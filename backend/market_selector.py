# market_selector.py

from market_config import LOCATION_MARKETS, MARKET_QUALITY_ACCEPTANCE

def get_eligible_markets(location: str, quality: str):
    nearby_markets = LOCATION_MARKETS.get(location, [])

    eligible = [
        market for market in nearby_markets
        if quality in MARKET_QUALITY_ACCEPTANCE.get(market, [])
    ]

    return eligible