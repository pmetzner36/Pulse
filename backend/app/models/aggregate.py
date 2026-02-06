"""Pydantic schemas for aggregated mood data."""

from datetime import datetime
from typing import List, Optional
from enum import Enum
from pydantic import BaseModel, Field


class TrendDirection(str, Enum):
    """Trend direction for metrics."""
    rising = "rising"
    falling = "falling"
    stable = "stable"


class MoodCategory(str, Enum):
    """Mood quadrant categories."""
    excited = "excited"
    tense = "tense"
    calm = "calm"
    fatigued = "fatigued"


class AggregateTileOut(BaseModel):
    """Aggregated mood data for a geographic tile."""
    h3_index: str
    time_bucket: datetime
    sample_count: int
    mean_stress: float
    mean_energy: float
    variance: float
    trend: TrendDirection
    confidence: float
    center_lat: Optional[float] = None
    center_lng: Optional[float] = None


class MapResponse(BaseModel):
    """Response for map data request."""
    tiles: List[AggregateTileOut]
    city_id: str
    time_window: str
    generated_at: datetime


class InsightType(str, Enum):
    """Types of insights."""
    spike = "spike"
    comparison = "comparison"
    trend = "trend"
    personal = "personal"


class InsightCardOut(BaseModel):
    """Insight card for display."""
    id: str
    type: InsightType
    title: str
    description: str
    region: str
    timestamp: datetime
    metric_value: Optional[float] = None
    metric_label: Optional[str] = None


class InsightsResponse(BaseModel):
    """Response for insights request."""
    insights: List[InsightCardOut]
    city_id: str
    generated_at: datetime
