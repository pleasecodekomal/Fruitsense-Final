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
# Load Models
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
        MODEL_MAP[fruit] = model
        print(f"[MODEL] Loaded {fruit}")

    except Exception as e:
        print(f"[MODEL ERROR] {fruit}: {e}")

print("Available fruits:", MODEL_MAP.keys())

# =====================
# Helpers
# =====================

def grade_from_score(score):

    if score >= 70:
        return 1   # High quality
    elif score >= 40:
        return 2   # Medium quality
    else:
        return 3   # Poor quality

# =====================
# Prediction
# =====================

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
# Gemini Quality Summary
# =====================

def generate_quality_summary(fruit, grade, confidence, pred_class):

    api_key = os.getenv("GEMINI_API_KEY")

    fallback = f"The {fruit} is graded {grade} with a confidence of {confidence*100:.1f}%."

    if not api_key:
        return fallback

    try:

        prompt = f"""
        You are an agricultural quality expert.

        Fruit: {fruit}
        Condition predicted: {pred_class}
        Grade level: {grade} (1 = high quality, 3 = poor quality)
        Confidence: {confidence*100:.1f}%

        Explain in 2–3 sentences what this means about freshness,
        quality, and whether it is suitable for sale or consumption.
        """

        api_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
        payload = {
            "contents": [
                {
                    "parts": [{"text": prompt}]
                }
            ]
        }

        response = requests.post(api_url, json=payload, timeout=20)

        if response.status_code != 200:
            print("Gemini failed:", response.text)
            return fallback

        result = response.json()

        return result['candidates'][0]['content']['parts'][0]['text']

    except Exception as e:

        print("Gemini summary error:", e)
        return fallback


# =====================
# Quality Route
# =====================

@app.route("/summarize_quality", methods=["POST"])
def summarize_quality():

    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400

    fruit = request.form.get("fruit", "").lower().strip()

    if fruit not in MODEL_MAP:
        return jsonify({"error": "Invalid fruit"}), 400

    file = request.files['file']

    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    filename = f"{datetime.now().timestamp()}_{secure_filename(file.filename)}"

    filepath = os.path.join(UPLOAD_FOLDER, filename)

    file.save(filepath)

    try:

        pred_class, confidence, score, grade = predict_and_grade(filepath, fruit)

        summary = generate_quality_summary(
            fruit,
            grade,
            confidence,
            pred_class
        )

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

        return jsonify({
            "class": pred_class,
            "confidence": round(confidence, 2),
            "score": round(score, 1),
            "grade": grade,
            "summary": summary
        })

    except Exception as e:

        print("Prediction failed:", e)

        return jsonify({"error": str(e)}), 500


# =====================
# Gemini Price Prediction
# =====================

def get_price_from_genai(quality_grade, market, variety, arrivals):

    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        return random.randint(3000, 6000)

    try:

        if not os.path.exists(SUPPLIER_DATA):
            return random.randint(3000, 6000)

        df = pd.read_csv(SUPPLIER_DATA)

        if df.empty:
            return random.randint(3000, 6000)

        examples = df.sample(min(3, len(df)))

        prompt = "Estimate fruit price.\n"

        for _, row in examples.iterrows():

            prompt += f"""
Market: {row.get('Market Name', '')}
Variety: {row.get('Variety', '')}
Arrivals: {row.get('Arrivals (Tonnes)', '')}
Price: {row.get('Modal Price (Rs./Quintal)', '')}
"""

        prompt += f"""
New prediction:

Grade: {quality_grade}
Market: {market}
Variety: {variety}
Arrivals: {arrivals}

Price:
"""

        api_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

        payload = {
            "contents": [
                {"parts": [{"text": prompt}]}
            ]
        }

        response = requests.post(api_url, json=payload, timeout=20)

        if response.status_code != 200:
            return random.randint(3000, 6000)

        result = response.json()

        text = result['candidates'][0]['content']['parts'][0]['text']

        cleaned = ''.join(filter(str.isdigit, text))

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

    fruit = request.form.get("fruit", "apple").lower().strip()

    if fruit not in MODEL_MAP:
        return jsonify({"error": "Invalid fruit"}), 400

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
# Market Recommendation
# =====================

@app.route("/recommend_market", methods=["POST"])
def recommend_market():

    data = request.json

    location = data.get("location")
    quality = data.get("quality")
    fruit = data.get("fruit", "apple")

    if not location or not quality:
        return jsonify({"error": "Missing location or quality"}), 400

    eligible_markets = get_eligible_markets(location, quality)

    if not eligible_markets:
        return jsonify({
            "recommended_market": None,
            "reason": f"No nearby markets in {location} accept grade {quality}.",
            "eligible_markets": []
        })

    recommended = eligible_markets[0]

    if quality == 1:
        reason = f"High-quality {fruit}s are best suited for premium wholesale markets."
    elif quality == 2:
        reason = f"Medium-quality {fruit}s perform well in mixed retail and wholesale markets."
    else:
        recommended = eligible_markets[-1]
        reason = f"Lower-quality {fruit}s are better suited for local markets."
        
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

    grade_map = {1: 3, 2: 2, 3: 1}

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
# Run Server
# =====================

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)