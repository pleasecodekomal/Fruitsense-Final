# market_selector.py

import os
import requests
from dotenv import load_dotenv
from market_config import LOCATION_MARKETS, MARKET_QUALITY_ACCEPTANCE

load_dotenv()


# =========================
# Get eligible markets
# =========================

def get_eligible_markets(location: str, quality):

    quality = str(quality)

    nearby_markets = LOCATION_MARKETS.get(location, [])

    eligible = []

    for market in nearby_markets:

        accepted_grades = MARKET_QUALITY_ACCEPTANCE.get(market, [])

        accepted_grades = [str(g) for g in accepted_grades]

        if quality in accepted_grades:
            eligible.append(market)

    return eligible


# =========================
# Gemini Market Explanation
# =========================

def generate_market_reason(fruit, grade, location, market):

    api_key = os.getenv("GEMINI_API_KEY")

    fallback = f"{market} is suitable for Grade {grade} {fruit}s in {location}."

    if not api_key:
        return fallback

    try:

        prompt = f"""
You are an agricultural market advisor.

Fruit: {fruit}
Quality grade: {grade}
Farmer location: {location}
Recommended market: {market}

Explain in 2 short sentences why this market is suitable
for selling this fruit quality. Focus on demand, pricing,
and typical buyers.
"""

        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"

        payload = {
            "contents": [
                {"parts": [{"text": prompt}]}
            ]
        }

        response = requests.post(url, json=payload, timeout=20)

        if response.status_code != 200:
            print("Gemini market explanation failed:", response.text)
            return fallback

        result = response.json()

        return result['candidates'][0]['content']['parts'][0]['text']

    except Exception as e:

        print("Gemini market summary error:", e)

        return fallback


# =========================
# Full recommendation logic
# =========================

def recommend_market(location, quality, fruit):

    eligible_markets = get_eligible_markets(location, quality)

    if not eligible_markets:

        return {
            "recommended_market": None,
            "reason": f"No nearby markets in {location} accept grade {quality}.",
            "eligible_markets": []
        }

    # First eligible market is recommended
    recommended = eligible_markets[0]

    reason = generate_market_reason(
        fruit,
        quality,
        location,
        recommended
    )

    return {
        "recommended_market": recommended,
        "reason": reason,
        "eligible_markets": eligible_markets
    }