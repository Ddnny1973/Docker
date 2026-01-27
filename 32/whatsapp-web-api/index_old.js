import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import pkg from 'whatsapp-web.js';
import qrcode from 'qrcode-terminal';
import fs from 'fs';
import path from 'path';

const { Client, LocalAuth } = pkg;
const app = express();
app.use(express.json());

const SESSION_ID = process.env.WPP_SESSION_ID || 'default';
const ENABLE_RECEIVE_MESSAGES = process.env.ENABLE_RECEIVE_MESSAGES === 'true';
const WEBHOOK_URL = process.env.WEBHOOK_URL || null;
const SAVE_MEDIA = process.env.SAVE_MEDIA === 'true';
const MEDIA_PATH = process.env.MEDIA_PATH || '/app/media';

let client;
let clientReady = false; // Flag para saber si el cliente está completamente listo

// Función para crear directorios si no existen
const ensureDirectoryExists = (dirPath) => {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
        console.log(`📁 Directorio creado: ${dirPath}`);
    }
};

// Función para guardar archivos de media
const saveMediaFile = async (media, messageId, type, contactName) => {
    try {
        const date = new Date();
        const dateFolder = date.toISOString().split('T')[0]; // YYYY-MM-DD
        
        // Estructura: /media/YYYY-MM-DD/tipo/
        const mediaDir = path.join(MEDIA_PATH, dateFolder, type);
        ensureDirectoryExists(mediaDir);
        
        // Nombre de archivo: timestamp_contactName_messageId.ext
        const timestamp = Date.now();
        const safeName = contactName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 30);
        const extension = media.mimetype.split('/')[1] || 'bin';
        const fileName = `${timestamp}_${safeName}_${messageId.substring(0, 20)}.${extension}`;
        const filePath = path.join(mediaDir, fileName);
        
        // Guardar archivo
        const buffer = Buffer.from(media.data, 'base64');
        fs.writeFileSync(filePath, buffer);
        
        console.log(`💾 Media guardado: ${filePath} (${(buffer.length / 1024).toFixed(2)} KB)`);
        
        return {
            file_path: filePath,
            file_name: fileName,
            file_size: buffer.length,
            mime_type: media.mimetype,
            relative_path: path.join(dateFolder, type, fileName) // para BD
        };
    } catch (error) {
        console.error(`❌ Error guardando media:`, error);
        return null;
    }
};

const startClient = () => {
    try {
        client = new Client({
            authStrategy: new LocalAuth({ 
                clientId: SESSION_ID,
                dataPath: '/app/.wwebjs_auth'
            }),
            puppeteer: {
                headless: true,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--no-zygote'
                ]
            }
        });

        client.on('qr', qr => {
            console.log(`🟡 Escanea este QR para vincular la sesión: ${SESSION_ID}`);
            qrcode.generate(qr, { small: true });
            clientReady = false; // No está listo mientras pide QR
        });

        client.on('ready', () => {
            console.log(`✅ Cliente WhatsApp listo (${SESSION_ID})`);
            clientReady = true; // Marcar cliente como listo
        });
        client.on('authenticated', () => {
            console.log(`🔐 Cliente autenticado (${SESSION_ID})`);
        });
        client.on('auth_failure', msg => {
            console.error(`❌ Fallo de autenticación (${SESSION_ID}):`, msg);
            clientReady = false;
        });
        client.on('disconnected', (reason) => {
            console.warn(`⚠️ Cliente desconectado (${SESSION_ID}): ${reason}`);
            clientReady = false; // Marcar cliente como no listo
            
            // Solo reiniciar si NO es un LOGOUT (que indica cierre de sesión intencional)
            if (reason !== 'LOGOUT') {
                console.log(`🔄 Reiniciando cliente en 5 segundos...`);
                client.destroy();
                setTimeout(() => startClient(), 5000);
            } else {
                console.log(`🛑 Sesión cerrada por LOGOUT - no se reiniciará automáticamente`);
                client.destroy();
            }
        });

        // Evento para recibir mensajes (solo si está habilitado)
        if (ENABLE_RECEIVE_MESSAGES) {
            console.log(`📨 Recepción de mensajes ACTIVADA para sesión: ${SESSION_ID}`);
            client.on('message_create', async (msg) => {
                console.log(`🔔 Evento 'message_create' disparado - isStatus: ${msg.isStatus}, fromMe: ${msg.fromMe}`);
                try {
                    // Ignorar solo mensajes de estados (stories)
                    if (msg.isStatus) {
                        console.log(`⏭️  Mensaje ignorado: es un estado/story`);
                        return;
                    }

                    let contact = null;
                    let contactName = msg.from;
                    try {
                        contact = await msg.getContact();
                        contactName = contact.pushname || contact.name || msg.from;
                    } catch (err) {
                        console.warn(`⚠️  No se pudo obtener el contacto: ${err.message}`);
                    }
                    const chat = await msg.getChat();
                    
                    const messageData = {
                        sessionId: SESSION_ID,
                        timestamp: new Date().toISOString(),
                        from: msg.from,
                        contactName: contactName,
                        body: msg.body,
                        type: msg.type,
                        isGroup: chat.isGroup,
                        groupName: chat.isGroup ? chat.name : null,
                        hasMedia: msg.hasMedia,
                        messageId: msg.id._serialized,
                        fromMe: msg.fromMe,
                        // Campos de media (aplanados para facilitar el uso en n8n)
                        media_file_path: null,
                        media_file_name: null,
                        media_file_size: null,
                        media_mime_type: null,
                        media_relative_path: null
                    };

                    // Descargar y guardar media si está habilitado y el mensaje tiene media
                    if (SAVE_MEDIA && msg.hasMedia) {
                        try {
                            console.log(`📥 Descargando media (${msg.type})...`);
                            const media = await msg.downloadMedia();
                            
                            if (media) {
                                const mediaData = await saveMediaFile(
                                    media, 
                                    msg.id._serialized, 
                                    msg.type,
                                    messageData.contactName
                                );
                                
                                if (mediaData) {
                                    // Aplanar los datos de media directamente en messageData
                                    messageData.media_file_path = mediaData.file_path;
                                    messageData.media_file_name = mediaData.file_name;
                                    messageData.media_file_size = mediaData.file_size;
                                    messageData.media_mime_type = mediaData.mime_type;
                                    messageData.media_relative_path = mediaData.relative_path;
                                }
                            }
                        } catch (mediaError) {
                            console.error(`❌ Error descargando media:`, mediaError);
                        }
                    }

                    const messageIcon = msg.fromMe ? '📤' : '📩';
                    const messageType = msg.fromMe ? 'enviado' : 'recibido';
                    
                    console.log(`${messageIcon} Mensaje ${messageType} (${SESSION_ID}):`, {
                        from: messageData.contactName,
                        message: msg.body.substring(0, 100),
                        fromMe: msg.fromMe
                    });

                    // Enviar a webhook si está configurado
                    if (WEBHOOK_URL) {
                        try {
                            const response = await fetch(WEBHOOK_URL, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify(messageData)
                            });
                            
                            if (response.ok) {
                                console.log(`✅ Mensaje enviado a webhook (${SESSION_ID})`);
                            } else {
                                console.error(`❌ Error enviando a webhook (${SESSION_ID}): ${response.status}`);
                            }
                        } catch (webhookError) {
                            console.error(`❌ Error al llamar webhook (${SESSION_ID}):`, webhookError.message);
                        }
                    }
                } catch (error) {
                    console.error(`❌ Error procesando mensaje (${SESSION_ID}):`, error);
                }
            });
        } else {
            console.log(`🚫 Recepción de mensajes DESACTIVADA para sesión: ${SESSION_ID}`);
        }

        client.initialize();

    } catch (error) {
        console.error(`🔥 Error al inicializar cliente (${SESSION_ID}):`, error);
        setTimeout(() => startClient(), 10000);
    }
};

startClient();

app.post('/send', async (req, res) => {
    const { number, message } = req.body;
    if (!number || !message) return res.status(400).json({ error: 'number y message son requeridos' });

    // Verificar si el cliente está listo
    if (!clientReady || !client) {
        return res.status(503).json({ error: 'Cliente WhatsApp no está listo. Intenta nuevamente en unos segundos.' });
    }

    try {
        const chatId = `${number}@c.us`;
        
        // Agregar retry logic y timeout para isRegisteredUser
        let isRegistered = false;
        let retries = 3;
        
        while (retries > 0 && !isRegistered) {
            try {
                // Timeout de 5 segundos para la operación
                isRegistered = await Promise.race([
                    client.isRegisteredUser(chatId),
                    new Promise((_, reject) => 
                        setTimeout(() => reject(new Error('Timeout verificando usuario')), 5000)
                    )
                ]);
                break;
            } catch (error) {
                retries--;
                if (retries === 0) {
                    console.error(`❌ Error verificando usuario después de reintentos:`, error.message);
                    // En caso de error, intentar enviar de todas formas
                    console.log(`⚠️ Intentando enviar mensaje sin verificación previa...`);
                    break;
                }
                console.log(`⚠️ Reintentando verificación de usuario... (${retries} intentos restantes)`);
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
        }
        
        // Si no pudimos verificar pero queremos intentar enviar de todas formas
        if (!isRegistered && retries === 0) {
            console.log(`⚠️ Enviando mensaje sin verificación confirmada a ${number}`);
        } else if (!isRegistered) {
            return res.status(404).json({ error: 'Usuario no registrado en WhatsApp' });
        }
        
        await client.sendMessage(chatId, message);
        res.json({ status: 'enviado', number });
    } catch (error) {
        console.error(`❌ Error enviando mensaje (${SESSION_ID}):`, error);
        res.status(500).json({ error: error.toString() });
    }
});

app.get('/status', (req, res) => {
    res.json({ 
        status: clientReady ? 'ready' : 'not_ready',
        session: SESSION_ID,
        message: clientReady ? `🔋 API WhatsApp (${SESSION_ID}) funcionando` : `⏳ API WhatsApp (${SESSION_ID}) iniciando...`
    });
});

app.listen(3000, () => console.log(`🚀 API WhatsApp (${SESSION_ID}) escuchando en puerto 3000`));
