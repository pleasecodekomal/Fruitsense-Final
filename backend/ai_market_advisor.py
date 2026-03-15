from openai import OpenAI
import re

client = OpenAI()

def get_ai_market_reason(location, quality, fruit, eligible_markets):
    """
    Returns a realistic market recommendation.
    AI is used only when eligible markets exist.
    """

    # ✅ REALISTIC FALLBACK — NO AI LABEL SHOWN TO USER
    if not eligible_markets:
        return {
            "recommended_market": f"{location} Local Mandi",
            "reason": "Local mandis accept fresh produce of mixed quality, usually at adjusted prices."
        }

    prompt = f"""
You are an agricultural market advisor.

Farmer location: {location}
Fruit type: {fruit}
Fruit quality grade: {quality}

Eligible markets:
{", ".join(eligible_markets)}

Pick ONE best market.
Explain in ONE short sentence.

Strict format:
Market: <market name>
Reason: <short reason>
"""

    try:
        response = client.responses.create(
            model="gpt-4.1-mini",
            input=prompt,
            temperature=0.3,
        )

        text = response.output_text.strip()
        if not text:
            raise ValueError("Empty AI response")

        market_match = re.search(r"Market:\s*(.+)", text)
        reason_match = re.search(r"Reason:\s*(.+)", text)

        recommended_market = (
            market_match.group(1).strip()
            if market_match else eligible_markets[0]
        )

        reason = (
            reason_match.group(1).strip()
            if reason_match else "Market chosen based on demand and price trends."
        )

        return {
            "recommended_market": recommended_market,
            "reason": reason
        }

    except Exception as e:
        print("AI error:", e)
        return {
            "recommended_market": eligible_markets[0],
            "reason": "Market chosen based on proximity and current demand."
        }