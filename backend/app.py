from flask import Flask, request, jsonify
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
from market_selector import get_eligible_markets
import numpy as np
import os
import pandas as pd
from datetime import datetime
from flask_cors import CORS
from dotenv import load_dotenv
import requests
import random
from werkzeug.utils import secure_filename

# =====================
# Setup
# =====================
load_dotenv()

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = "uploads"
DATA_LOG = "graded_fruits.csv"
SUPPLIER_DATA = "supplier_dataset (1).csv"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# =====================
# Load Models (Fruit-specific)
# =====================
MODEL_MAP = {}
INPUT_SIZE_MAP = {
    "apple": (128, 128),
    "banana": (224, 224),
    "orange": (224, 224),
}

CLASS_LABELS = ['Formalin-mixed', 'Fresh', 'Rotten']
QUALITY_WEIGHTS = {
    'Fresh': 100,
    'Formalin-mixed': 50,
    'Rotten': 0
}

for fruit, path in {
    "apple": "models/apple/model.h5",
    "banana": "models/banana/model.h5",
    "orange": "models/orange/model.h5"
}.items():
    try:
        model = load_model(path, compile=False)
        print(f"[DEBUG] Loaded model for {fruit} from {path}")
        MODEL_MAP[fruit] = model
    except Exception as e:
        print(f"Error loading {fruit} model: {e}")

# =====================
# Helpers
# =====================
def grade_from_score(score):
    if score >= 85: return 'A'
    elif score >= 70: return 'B'
    elif score >= 50: return 'C'
    elif score >= 30: return 'D'
    else: return 'F'


def predict_and_grade(img_path, fruit):
    if fruit not in MODEL_MAP:
        raise ValueError("Invalid fruit selected")

    model = MODEL_MAP[fruit]
    target_size = INPUT_SIZE_MAP[fruit]

    img = image.load_img(img_path, target_size=target_size)
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0) / 255.0

    preds = model.predict(img_array)[0]
    pred_idx = int(np.argmax(preds))

    pred_class = CLASS_LABELS[pred_idx]
    confidence = float(preds[pred_idx])

    score = float(sum(
        preds[i] * QUALITY_WEIGHTS[CLASS_LABELS[i]]
        for i in range(len(CLASS_LABELS))
    ))

    grade = grade_from_score(score)
    return pred_class, confidence, score, grade


# =====================
# Quality Route
# =====================
@app.route("/summarize_quality", methods=["POST"])
def summarize_quality():
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400

    fruit = request.form.get("fruit")
    if fruit not in MODEL_MAP:
        return jsonify({"error": "Invalid or missing fruit"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    filename = f"{datetime.now().timestamp()}_{secure_filename(file.filename)}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)

    try:
        pred_class, confidence, score, grade = predict_and_grade(filepath, fruit)

        log_entry = pd.DataFrame([{
            "filename": filename,
            "fruit": fruit,
            "prediction": pred_class,
            "confidence": round(confidence, 2),
            "score": round(score, 1),
            "grade": grade,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }])

        log_entry.to_csv(
            DATA_LOG,
            mode="a",
            header=not os.path.exists(DATA_LOG),
            index=False
        )

        # ✅ Add summary here
        return jsonify({
            "class": pred_class,
            "confidence": round(confidence, 2),
            "score": round(score, 1),
            "grade": grade,
            "summary": f"The {fruit} is graded {grade} with a confidence of {round(confidence, 2)*100:.1f}%."
        })

    except Exception as e:
        print(f"[ERROR] Prediction failed: {e}")
        return jsonify({"error": str(e)}), 500

# =====================
# Price Prediction Helper
# =====================
def get_price_from_genai(quality_grade, market, variety, arrivals):
    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        print("No Gemini key found, using fallback price")
        return random.randint(3000, 6000)

    try:
        if not os.path.exists(SUPPLIER_DATA):
            print("Supplier dataset missing, using fallback price")
            return random.randint(3000, 6000)

        df = pd.read_csv(SUPPLIER_DATA)
        if df.empty:
            return random.randint(3000, 6000)

        examples = df.sample(min(3, len(df)))
        prompt = "Estimate apple price.\n"
        for _, row in examples.iterrows():
            prompt += f"""
Market: {row.get('Market Name', '')}
Variety: {row.get('Variety', '')}
Arrivals: {row.get('Arrivals (Tonnes)', '')}
Price: {row.get('Modal Price (Rs./Quintal)', '')}
"""

        prompt += f"""
New:
Grade: {quality_grade}
Market: {market}
Variety: {variety}
Arrivals: {arrivals}
Price:
"""

        api_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key={api_key}"
        payload = {"contents": [{"parts": [{"text": prompt}]}]}

        response = requests.post(api_url, json=payload, timeout=20)
        if response.status_code != 200:
            print("Gemini API failed:", response.text)
            return random.randint(3000, 6000)

        result = response.json()
        price_text = result['candidates'][0]['content']['parts'][0]['text']
        cleaned = ''.join(filter(str.isdigit, price_text))
        return float(cleaned) if cleaned else random.randint(3000, 6000)

    except Exception as e:
        print("Price prediction error:", e)
        return random.randint(3000, 6000)


# =====================
# Price Prediction Route
# =====================
@app.route("/predict_price", methods=["POST"])
def predict_price():
    if 'file' not in request.files:
        return jsonify({"error": "No image provided"}), 400

    file = request.files['file']
    market = request.form.get('market')
    variety = request.form.get('variety')
    arrivals = request.form.get('arrivals')

    if not all([market, variety, arrivals]):
        return jsonify({"error": "Missing inputs"}), 400

    filename = f"{datetime.now().timestamp()}_{secure_filename(file.filename)}"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)

    try:
        # Use the fruit from request or default to apple
        fruit = request.form.get("fruit", "apple")
        _, _, _, grade = predict_and_grade(filepath, fruit)

        price = get_price_from_genai(
            grade,
            market,
            variety,
            float(arrivals)
        )

        return jsonify({
            "estimated_price_per_quintal": round(price, 2),
            "quality_grade": grade
        })

    except Exception as e:
        print("Predict route error:", e)
        return jsonify({"error": str(e)}), 500


# =====================
# Market Recommendation Route
# =====================
@app.route("/recommend_market", methods=["POST"])
def recommend_market():
    data = request.json
    location = data.get("location")
    quality = data.get("quality")
    fruit = data.get("fruit", "Apple")

    if not location or not quality:
        return jsonify({"error": "Missing location or quality"}), 400

    eligible_markets = get_eligible_markets(location, quality)

    if not eligible_markets:
        return jsonify({
            "recommended_market": None,
            "reason": f"No nearby markets in {location} accept grade {quality}.",
            "eligible_markets": []
        })

    # Rule-based recommendation
    recommended = eligible_markets[0]
    if quality == "A":
        reason = f"Premium grade {fruit}s are best suited for high-demand wholesale markets."
    elif quality == "B":
        reason = f"Grade B {fruit}s perform well in balanced retail-wholesale markets."
    else:
        recommended = eligible_markets[-1]
        reason = f"Lower grade {fruit}s are better suited for local markets with flexible pricing."

    return jsonify({
        "recommended_market": recommended,
        "reason": reason,
        "eligible_markets": eligible_markets
    })


# =====================
# Stats Route
# =====================
@app.route("/api/stats", methods=["GET"])
def get_stats():
    if not os.path.exists(DATA_LOG):
        return jsonify({"totalGraded": 0, "avgQuality": "0%", "todayUploads": 0})

    df = pd.read_csv(DATA_LOG, on_bad_lines='skip')
    if df.empty:
        return jsonify({"totalGraded": 0, "avgQuality": "0%", "todayUploads": 0})

    grade_map = {'A': 6, 'B': 5, 'C': 4, 'D': 3, 'F': 1}
    df["gradeValue"] = df["grade"].map(grade_map).fillna(0)
    avg_quality = round(df["gradeValue"].mean() / 6 * 100, 2)
    df["timestamp"] = pd.to_datetime(df["timestamp"], errors="coerce")
    today = datetime.now().date()
    today_uploads = df[df["timestamp"].dt.date == today].shape[0]

    return jsonify({
        "totalGraded": len(df),
        "avgQuality": f"{avg_quality}%",
        "todayUploads": today_uploads
    })


# =====================
# Past Results Route
# =====================
@app.route("/api/past-results", methods=["GET"])
def past_results():
    if not os.path.exists(DATA_LOG):
        return jsonify([])
    df = pd.read_csv(DATA_LOG, on_bad_lines='skip')
    return jsonify(df.to_dict(orient="records"))


# =====================
# Delete Result Route
# =====================
@app.route("/api/delete-result", methods=["DELETE"])
def delete_result():
    filename = request.args.get("filename")
    timestamp = request.args.get("timestamp")
    if not filename or not timestamp:
        return jsonify({"error": "Missing parameters"}), 400
    if not os.path.exists(DATA_LOG):
        return jsonify({"error": "Data log not found"}), 404
    df = pd.read_csv(DATA_LOG, on_bad_lines='skip')
    initial_len = len(df)
    df = df[~((df["filename"] == filename) & (df["timestamp"] == timestamp))]
    df.to_csv(DATA_LOG, index=False)
    if len(df) < initial_len:
        return jsonify({"message": "Record deleted successfully"})
    else:
        return jsonify({"error": "Record not found"}), 404


# =====================
# Run Server
# =====================
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)