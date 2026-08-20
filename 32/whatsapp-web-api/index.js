console.log("Versión index.js: 2026-03-05.04");
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

// Limpiar SingletonLock de Chromium al iniciar (evita "profile in use")
const cleanSingletonLocks = () => {
    const authDir = '/app/.wwebjs_auth';
    try {
        if (fs.existsSync(authDir)) {
            const sessions = fs.readdirSync(authDir);
            for (const session of sessions) {
                const lockFile = path.join(authDir, session, 'SingletonLock');
                if (fs.existsSync(lockFile)) {
                    fs.unlinkSync(lockFile);
                    console.log(`🔓 SingletonLock eliminado: ${lockFile}`);
                }
            }
        }
    } catch (error) {
        console.warn(`⚠️ Error limpiando SingletonLocks: ${error.message}`);
    }
};
cleanSingletonLocks();

// Manejo de promesas rechazadas
process.on('unhandledRejection', (reason, promise) => {
    console.error(`⚠️ Promesa rechazada no manejada:`, reason);
});

process.on('uncaughtException', (error) => {
    console.error(`🔥 Excepción no capturada:`, error);
    setTimeout(() => {
        console.log('🔄 Intentando reiniciar después de excepción...');
        if (client) {
            client.destroy().catch(() => {}).then(() => {
                startClient();
            });
        }
    }, 5000);
});

const SESSION_ID = process.env.WPP_SESSION_ID || 'default';
const ENABLE_RECEIVE_MESSAGES = process.env.ENABLE_RECEIVE_MESSAGES === 'true';
const WEBHOOK_URL = process.env.WEBHOOK_URL || null;
const SAVE_MEDIA = process.env.SAVE_MEDIA === 'true';
const MEDIA_PATH = process.env.MEDIA_PATH || '/app/media';

let client;
let clientReady = false;

const ensureDirectoryExists = (dirPath) => {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
        console.log(`📁 Directorio creado: ${dirPath}`);
    }
};

const saveMediaFile = async (media, messageId, type, contactName) => {
    try {
        const date = new Date();
        const dateFolder = date.toISOString().split('T')[0];
        
        const mediaDir = path.join(MEDIA_PATH, dateFolder, type);
        ensureDirectoryExists(mediaDir);
        
        const timestamp = Date.now();
        const safeName = contactName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 30);
        const mimeType = media.mimetype || 'application/bin';
        const extension = (mimeType.split('/')[1] || 'bin').split(';')[0];
        const fileName = `${timestamp}_${safeName}_${messageId.substring(0, 20)}.${extension}`;
        const filePath = path.join(mediaDir, fileName);
        
        const buffer = Buffer.from(media.data, 'base64');
        fs.writeFileSync(filePath, buffer);
        
        console.log(`💾 Media guardado: ${filePath} (${(buffer.length / 1024).toFixed(2)} KB)`);
        
        return {
            file_path: filePath,
            file_name: fileName,
            file_size: buffer.length,
            mime_type: media.mimetype,
            relative_path: path.join(dateFolder, type, fileName),
            base64_data: media.data
        };
    } catch (error) {
        console.error(`❌ Error guardando media:`, error);
        return null;
    }
};

const startClient = async () => {
    try {
        client = new Client({
            authStrategy: new LocalAuth({ 
                clientId: SESSION_ID,
                dataPath: '/app/.wwebjs_auth'
            }),
            puppeteer: {
                headless: true,
                protocolTimeout: 120000,  // ⬅️ FIX 1: 120 segundos timeout
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--no-zygote',
                    '--disable-sync',
                    '--disable-sync-types=*',
                    '--disable-extensions',
                    '--no-first-run',
                    '--no-default-browser-check'
                ]
            }
        });

        client.on('qr', qr => {
            console.log(`🟡 Escanea este QR para vincular la sesión: ${SESSION_ID}`);
            qrcode.generate(qr, { small: true });
            clientReady = false;
        });

        client.on('ready', () => {
            console.log(`✅ Cliente WhatsApp listo (${SESSION_ID})`);
            clientReady = true;
        });
        
        client.on('authenticated', () => {
            console.log(`🔐 Cliente autenticado (${SESSION_ID})`);
            setTimeout(() => {
                if (!clientReady) {
                    console.log(`⚠️ ready event no llegó en 30s, activando de todas formas`);
                    clientReady = true;
                }
            }, 30000);
        });
        
        client.on('loading_screen', (percent, message) => {
            console.log(`⏳ Cargando... ${percent}% - ${message}`);
        });
        
        client.on('auth_failure', msg => {
            console.error(`❌ Fallo de autenticación (${SESSION_ID}):`, msg);
            clientReady = false;
        });
        
        client.on('disconnected', (reason) => {
            console.warn(`⚠️ Cliente desconectado (${SESSION_ID}): ${reason}`);
            clientReady = false;
            console.log(`🔄 Reiniciando cliente en 5 segundos...`);
            client.destroy().catch(() => {}).finally(() => {
                setTimeout(() => startClient(), 5000);
            });
        });

        if (ENABLE_RECEIVE_MESSAGES) {
            console.log(`📨 Recepción de mensajes ACTIVADA para sesión: ${SESSION_ID}`);
            
            client.on('message_create', async (msg) => {
                console.log(`🔔 Evento 'message_create' disparado - isStatus: ${msg.isStatus}, fromMe: ${msg.fromMe}, type: ${msg.type}`);
                
                try {
                    // Ignorar estados/stories
                    if (msg.isStatus) {
                        console.log(`⭐️ Mensaje ignorado: es un estado/story`);
                        return;
                    }

                    // Obtener nombre del contacto
                    let contactName = msg.from;
                    let chat = null;
                    
                    try {
                        chat = await msg.getChat();
                        contactName = chat.name || msg.from;
                    } catch (err) {
                        console.warn(`⚠️ No se pudo obtener info del chat: ${err.message}`);
                    }
                    
                    const isVoiceMessage = msg.type === 'ptt' || msg.type === 'audio';
                    
                    const messageData = {
                        sessionId: SESSION_ID,
                        timestamp: new Date().toISOString(),
                        from: msg.from,
                        contactName: contactName,
                        body: msg.body,
                        type: msg.type,
                        isGroup: chat?.isGroup || false,
                        groupName: chat?.isGroup ? chat.name : null,
                        hasMedia: msg.hasMedia,
                        isVoiceMessage: isVoiceMessage,
                        messageId: msg.id._serialized,
                        fromMe: msg.fromMe,
                        media_file_path: null,
                        media_file_name: null,
                        media_file_size: null,
                        media_mime_type: null,
                        media_relative_path: null,
                        media_base64: null
                    };

                    // ⬇️ FIX 2: Descarga de media con timeout y manejo de errores
                    if (SAVE_MEDIA && msg.hasMedia) {
                        try {
                            console.log(`📥 Intentando descargar media (${msg.type})...`);
                            
                            // Timeout manual de 45 segundos
                            const DOWNLOAD_TIMEOUT = 45000;
                            
                            const media = await Promise.race([
                                msg.downloadMedia(),
                                new Promise((_, reject) => 
                                    setTimeout(() => reject(new Error('Download timeout')), DOWNLOAD_TIMEOUT)
                                )
                            ]).catch(error => {
                                if (error.message.includes('timeout') || error.message.includes('Timeout')) {
                                    console.warn(`⏱️ Timeout descargando media después de ${DOWNLOAD_TIMEOUT/1000}s`);
                                } else {
                                    console.warn(`⚠️ Error descargando media: ${error.message}`);
                                }
                                return null;
                            });
                            
                            if (media) {
                                console.log(`✅ Media descargado exitosamente`);
                                const mediaData = await saveMediaFile(
                                    media, 
                                    msg.id._serialized, 
                                    msg.type,
                                    messageData.contactName
                                );
                                
                                if (mediaData) {
                                    messageData.media_file_path = mediaData.file_path;
                                    messageData.media_file_name = mediaData.file_name;
                                    messageData.media_file_size = mediaData.file_size;
                                    messageData.media_mime_type = mediaData.mime_type;
                                    messageData.media_relative_path = mediaData.relative_path;
                                    
                                    if (isVoiceMessage) {
                                        messageData.media_base64 = mediaData.base64_data;
                                        console.log(`🎤 Audio descargado con base64 para transcripción`);
                                    }
                                }
                            } else {
                                console.log(`⚠️ Continuando sin media - se envió solo metadata`);
                                messageData.media_download_error = 'timeout or download failed';
                            }
                        } catch (mediaError) {
                            console.error(`❌ Error inesperado procesando media:`, mediaError.message);
                            messageData.media_download_error = mediaError.message;
                        }
                    }

                    const messageIcon = msg.fromMe ? '📤' : '📩';
                    const messageType = msg.fromMe ? 'enviado' : 'recibido';
                    const voiceTag = isVoiceMessage ? '🎤 VOZ' : '';
                    
                    console.log(`${messageIcon} ${voiceTag} Mensaje ${messageType} (${SESSION_ID}):`, {
                        from: messageData.contactName,
                        message: msg.body.substring(0, 100),
                        fromMe: msg.fromMe
                    });

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
                                console.error(`❌ Error enviando a webhook: ${response.status}`);
                            }
                        } catch (webhookError) {
                            console.error(`❌ Error llamando webhook:`, webhookError.message);
                        }
                    }
                } catch (error) {
                    console.error(`❌ Error procesando mensaje:`, error);
                }
            });
        } else {
            console.log(`🚫 Recepción de mensajes DESACTIVADA`);
        }

        try {
            // Un solo initialize sin timeout extra — protocolTimeout (120s) ya maneja los cortes
            await client.initialize();
            console.log(`🔄 Cliente inicializado (${SESSION_ID})`);
        } catch (initError) {
            console.error(`⚠️ Error en initialize:`, initError.message);
            // No llamar initialize() de nuevo aquí: causaría double-init y múltiples ready events
            client.destroy().catch(() => {}).finally(() => {
                setTimeout(() => startClient(), 5000);
            });
        }
    } catch (error) {
        console.error(`🔥 Error inicializando cliente:`, error);
        setTimeout(() => startClient(), 10000);
    }
};

startClient();

// ⬇️ FIX 3: Endpoint de envío mejorado para manejar grupos
app.post('/send', async (req, res) => {
    const { number, message } = req.body;
    
    if (!number || !message) {
        return res.status(400).json({ error: 'number y message son requeridos' });
    }

    if (!client || !client.pupPage) {
        return res.status(503).json({ 
            error: 'Cliente WhatsApp no está listo. Intenta en unos segundos.' 
        });
    }

    const waitForReady = async (maxWaitMs = 60000, intervalMs = 3000) => {
        const start = Date.now();
        while (Date.now() - start < maxWaitMs) {
            if (clientReady) return true;
            await new Promise(r => setTimeout(r, intervalMs));
        }
        return clientReady;
    };

    if (!clientReady) {
        console.log(`⏳ Esperando que WhatsApp esté listo...`);
        const ready = await waitForReady();
        if (!ready) {
            return res.status(503).json({ 
                error: 'Cliente WhatsApp no está listo después de esperar.' 
            });
        }
    }

    let chatId;
    if (number.includes('@g.us') || number.includes('@c.us') || number.includes('@')) {
        chatId = number;
    } else {
        chatId = `${number}@c.us`;
    }

    const MAX_RETRIES = 3;
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        try {
            console.log(`📤 Enviando mensaje a: ${chatId} (intento ${attempt}/${MAX_RETRIES})`);
            await client.sendMessage(chatId, message);
            console.log(`✅ Mensaje enviado a ${chatId}: ${message.substring(0, 50)}...`);
            return res.json({ status: 'enviado', number: chatId });
        } catch (error) {
            console.error(`❌ Error enviando mensaje (intento ${attempt}):`, error.message);
            
            if (attempt < MAX_RETRIES) {
                console.log(`🔄 Reintentando en ${attempt * 3}s...`);
                await new Promise(r => setTimeout(r, attempt * 3000));
            }
        }
    }
    
    res.status(500).json({ error: 'Error enviando mensaje después de múltiples intentos' });
});

app.get('/status', (req, res) => {
    res.json({ 
        status: clientReady ? 'ready' : 'not_ready',
        session: SESSION_ID,
        message: clientReady ? 
            `📋 API WhatsApp (${SESSION_ID}) funcionando` : 
            `⏳ API WhatsApp (${SESSION_ID}) iniciando...`
    });
});

app.get('/restart', async (req, res) => {
    console.log(`🔄 Reinicio solicitado para sesión: ${SESSION_ID}`);
    clientReady = false;
    try {
        if (client) {
            await client.destroy().catch(() => {});
        }
    } catch (e) {}
    res.json({ status: 'reiniciando', session: SESSION_ID });
    setTimeout(() => startClient(), 3000);
});

app.listen(3000, () => {
    console.log(`🚀 API WhatsApp (${SESSION_ID}) escuchando en puerto 3000`);
});