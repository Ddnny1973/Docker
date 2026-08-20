from flask import Flask, request, jsonify
from pdf2image import convert_from_bytes
from sentence_transformers import SentenceTransformer
from PIL import Image
import base64
import io

app = Flask(__name__)

# Cargar modelo de embeddings (lazy loading)
_embedding_model = None

def get_embedding_model():
    global _embedding_model
    if _embedding_model is None:
        _embedding_model = SentenceTransformer('distiluse-base-multilingual-cased-v2')
    return _embedding_model

@app.route("/pdf-to-images", methods=["POST"])
def pdf_to_images():
    try:
        # PDF desde archivo o base64
        if "file" in request.files:
            pdf_bytes = request.files["file"].read()
        elif request.is_json and "base64" in request.json:
            pdf_bytes = base64.b64decode(request.json["base64"])
        else:
            return jsonify({"error": "No PDF provided"}), 400

        # Convertir PDF a imágenes
        images = convert_from_bytes(pdf_bytes, dpi=300)

        # Convertir cada imagen a base64
        images_base64 = []
        for img in images:
            buffer = io.BytesIO()
            img.save(buffer, format="JPEG")
            img_b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")
            images_base64.append(img_b64)

        return jsonify({
            "pages": len(images),
            "images_base64": images_base64
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/embed", methods=["POST"])
def embed():
    try:
        data = request.json
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "text is required"}), 400
        
        model = get_embedding_model()
        embedding = model.encode(text).tolist()
        
        return jsonify({
            "embedding": embedding,
            "dimensions": len(embedding)
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
