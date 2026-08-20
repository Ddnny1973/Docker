import os
import base64
import tempfile
from flask import Flask, request, jsonify
from openai import OpenAI
from pydub import AudioSegment
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inicializar cliente de OpenAI
client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

def convert_ogg_to_mp3(ogg_path):
    """Convierte archivo OGG a MP3 para mejor compatibilidad"""
    try:
        audio = AudioSegment.from_file(ogg_path, format="ogg")
        mp3_path = ogg_path.replace('.ogg', '.mp3')
        audio.export(mp3_path, format="mp3")
        return mp3_path
    except Exception as e:
        logger.error(f"Error convirtiendo audio: {e}")
        return ogg_path  # Retornar original si falla

@app.route('/health', methods=['GET'])
def health():
    """Endpoint de salud"""
    return jsonify({"status": "healthy", "service": "transcription"}), 200

@app.route('/transcribe', methods=['POST'])
def transcribe_audio():
    """
    Transcribe un archivo de audio usando Whisper de OpenAI
    
    Acepta:
    - file: archivo de audio (multipart/form-data)
    - audio_base64: audio en base64 (JSON)
    - language: idioma opcional (default: español)
    """
    try:
        temp_file = None
        audio_file = None
        
        # Obtener idioma (default español)
        language = request.form.get('language', 'es') if request.files else request.json.get('language', 'es')
        
        # Opción 1: Archivo subido directamente
        if 'file' in request.files:
            audio_file = request.files['file']
            file_ext = audio_file.filename.split('.')[-1].lower()
            
            # Crear archivo temporal
            with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_ext}') as temp:
                audio_file.save(temp.name)
                temp_file = temp.name
        
        # Opción 2: Audio en base64
        elif request.json and 'audio_base64' in request.json:
            audio_data = base64.b64decode(request.json['audio_base64'])
            file_ext = request.json.get('file_extension', 'ogg')
            
            # Crear archivo temporal
            with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_ext}') as temp:
                temp.write(audio_data)
                temp_file = temp.name
        
        else:
            return jsonify({"error": "No se proporcionó archivo de audio"}), 400
        
        # Convertir OGG a MP3 si es necesario (WhatsApp usa OGG)
        if temp_file.endswith('.ogg'):
            logger.info("Convirtiendo OGG a MP3...")
            temp_file = convert_ogg_to_mp3(temp_file)
        
        # Transcribir con Whisper
        logger.info(f"Transcribiendo audio en idioma: {language}")
        with open(temp_file, 'rb') as audio:
            transcript = client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe-2025-03-20",
                file=audio,
                language=language,
                response_format="json"
            )
        
        # Limpiar archivo temporal
        if temp_file and os.path.exists(temp_file):
            os.unlink(temp_file)
            # Limpiar también el MP3 si se creó
            mp3_path = temp_file.replace('.ogg', '.mp3')
            if os.path.exists(mp3_path):
                os.unlink(mp3_path)
        
        result = {
            "success": True,
            "text": transcript.text,
            "language": language
        }
        
        logger.info(f"Transcripción exitosa: {transcript.text[:100]}...")
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error en transcripción: {str(e)}")
        
        # Limpiar archivo temporal en caso de error
        if temp_file and os.path.exists(temp_file):
            os.unlink(temp_file)
        
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/transcribe-url', methods=['POST'])
def transcribe_from_url():
    """
    Transcribe un archivo de audio desde una URL o ruta local
    
    Body JSON:
    {
        "file_path": "/path/to/audio.ogg",
        "language": "es"  // opcional
    }
    """
    try:
        data = request.json
        file_path = data.get('file_path')
        language = data.get('language', 'es')

        if not file_path:
            return jsonify({"error": "file_path es requerido"}), 400

        # Normalizar ruta y evitar path-injection
        file_path = os.path.normpath(file_path)
        allowed_dirs = [
            '/app/wppapi-media/',
            '/app/wppapi-ai-media/',
            '/app/wppapi-ai-2-media/'
        ]

        # Si la ruta empieza con /app/media/, buscar en todas las variantes
        candidate_paths = [file_path]
        if file_path.startswith('/app/media/'):
            candidate_paths = [
                file_path.replace('/app/media/', '/app/wppapi-media/'),
                file_path.replace('/app/media/', '/app/wppapi-ai-media/'),
                file_path.replace('/app/media/', '/app/wppapi-ai-2-media/')
            ]

        # Buscar el archivo en las rutas posibles y validar que esté dentro de los directorios permitidos
        real_path = None
        for path in candidate_paths:
            path = os.path.normpath(path)
            if any(path.startswith(d) for d in allowed_dirs) and os.path.exists(path):
                real_path = path
                break

        if not real_path:
            return jsonify({"error": f"Archivo no encontrado en rutas permitidas: {candidate_paths}"}), 404

        # Convertir OGG a MP3 si es necesario
        audio_path = real_path
        if real_path.endswith('.ogg'):
            logger.info("Convirtiendo OGG a MP3...")
            audio_path = convert_ogg_to_mp3(real_path)

        # Transcribir
        logger.info(f"Transcribiendo audio desde: {audio_path}")
        with open(audio_path, 'rb') as audio:
            transcript = client.audio.transcriptions.create(
                model="gpt-4o-mini-transcribe-2025-03-20",
                file=audio,
                language=language,
                response_format="json"
            )

        # Limpiar MP3 temporal si se creó
        if audio_path != real_path and os.path.exists(audio_path):
            os.unlink(audio_path)

        result = {
            "success": True,
            "text": transcript.text,
            "language": language,
            "file_path": real_path
        }

        logger.info(f"Transcripción exitosa: {transcript.text[:100]}...")
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error en transcripción desde URL: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == '__main__':
    # Verificar que existe la API key
    if not os.getenv('OPENAI_API_KEY'):
        logger.warning("⚠️ OPENAI_API_KEY no está configurada")
    
    app.run(host='0.0.0.0', port=5000, debug=False)