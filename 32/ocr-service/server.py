from flask import Flask, request, jsonify
from PIL import Image
import pytesseract
import base64
import io

app = Flask(__name__)

@app.route('/ocr', methods=['POST'])
def ocr():
    data = request.get_json()

    if not data or 'base64Image' not in data:
        return jsonify({"error": "Missing base64Image field"}), 400

    try:
        base64_data = data['base64Image'].split(",")[1] if ',' in data['base64Image'] else data['base64Image']
        image_data = base64.b64decode(base64_data)
        image = Image.open(io.BytesIO(image_data))
        text = pytesseract.image_to_string(image, lang='spa')  # Puedes cambiar a 'eng', 'deu', etc.
        return jsonify({"text": text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

