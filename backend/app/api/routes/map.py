"""API routes for map data."""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...db.database import get_db
from ...models.aggregate import MapResponse
from ...services.aggregation import get_aggregates_for_window

router = APIRouter(prefix="/v1/map", tags=["map"])

# Mock city H3 indices (in production, would be stored/configured)
CITY_H3_INDICES = {
    "sf": [
        "872830828ffffff",
        "872830829ffffff",
        "87283082affffff",
        "87283082bffffff",
        "87283082cffffff",
    ],
    "nyc": [
        "872a1070dffffff",
        "872a1070effffff",
        "872a10700ffffff",
    ]
}


def parse_window(window: str) -> float:
    """Parse time window string to hours."""
    if window == "15m":
        return 0.25
    elif window == "1h":
        return 1.0
    elif window == "24h":
        return 24.0
    return 1.0


@router.get("", response_model=MapResponse)
async def get_map_data(
    city_id: str = Query(default="sf", description="City identifier"),
    window: str = Query(default="1h", description="Time window: 15m, 1h, or 24h"),
    db: Session = Depends(get_db)
):
    """
    Get mood map data for a city.

    Returns aggregated mood tiles that meet k-anonymity thresholds.
    Each tile represents a geographic area with at least 30 contributors.
    """
    h3_indices = CITY_H3_INDICES.get(city_id, CITY_H3_INDICES["sf"])
    window_hours = parse_window(window)

    tiles = get_aggregates_for_window(db, h3_indices, window_hours)

    return MapResponse(
        tiles=tiles,
        city_id=city_id,
        time_window=window,
        generated_at=datetime.utcnow()
    )


@router.get("/cities")
async def list_cities():
    """List available cities."""
    return {
        "cities": [
            {"id": "sf", "name": "San Francisco", "region_count": len(CITY_H3_INDICES["sf"])},
            {"id": "nyc", "name": "New York City", "region_count": len(CITY_H3_INDICES["nyc"])}
        ]
    }
