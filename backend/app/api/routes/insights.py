"""API routes for insights."""

from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...db.database import get_db
from ...models.aggregate import InsightsResponse
from ...services.insight_generator import generate_insights
from .map import CITY_H3_INDICES, parse_window

router = APIRouter(prefix="/v1/insights", tags=["insights"])


@router.get("", response_model=InsightsResponse)
async def get_insights(
    city_id: str = Query(default="sf", description="City identifier"),
    window: str = Query(default="1h", description="Time window: 15m, 1h, or 24h"),
    db: Session = Depends(get_db)
):
    """
    Get mood insights for a city.

    Returns generated insight cards based on mood trends, anomalies,
    and regional comparisons. All insights are based on aggregated
    data that meets privacy thresholds.
    """
    h3_indices = CITY_H3_INDICES.get(city_id, CITY_H3_INDICES["sf"])
    window_hours = parse_window(window)

    insights = generate_insights(db, h3_indices, window_hours)

    return InsightsResponse(
        insights=insights,
        city_id=city_id,
        generated_at=datetime.utcnow()
    )
