"""Pydantic schemas for mood samples."""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class MoodMetrics(BaseModel):
    """Mood metrics computed on-device."""
    stress: float = Field(ge=0.0, le=1.0, description="Stress level 0-1")
    energy: float = Field(ge=0.0, le=1.0, description="Energy level 0-1")


class MoodSampleIn(BaseModel):
    """Incoming mood sample from client."""
    timestamp: datetime
    h3_index: str = Field(min_length=15, max_length=15, description="H3 index at resolution 7")
    metrics: MoodMetrics
    signal_quality: float = Field(ge=0.0, le=1.0)
    contribution_flags: List[str] = Field(default_factory=list)


class SampleBatchIn(BaseModel):
    """Batch of samples for upload."""
    samples: List[MoodSampleIn]
    device_id: str
    app_version: str


class SampleBatchResponse(BaseModel):
    """Response for sample batch upload."""
    received: int
    message: str = "Samples received successfully"
