"""Aggregation service for mood samples."""

from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_

from ..db.models import MoodSample, AggregateBucket
from ..models.aggregate import TrendDirection, AggregateTileOut


# k-anonymity threshold
K_ANONYMITY_THRESHOLD = 30

# Time bucket size in minutes
BUCKET_SIZE_MINUTES = 15


def get_time_bucket(timestamp: datetime) -> datetime:
    """Round timestamp down to nearest bucket."""
    minutes = (timestamp.minute // BUCKET_SIZE_MINUTES) * BUCKET_SIZE_MINUTES
    return timestamp.replace(minute=minutes, second=0, microsecond=0)


def add_sample_to_bucket(
    db: Session,
    h3_index: str,
    timestamp: datetime,
    stress: float,
    energy: float
) -> AggregateBucket:
    """Add a sample to the appropriate aggregate bucket."""
    time_bucket = get_time_bucket(timestamp)

    # Find or create bucket
    bucket = db.query(AggregateBucket).filter(
        and_(
            AggregateBucket.h3_index == h3_index,
            AggregateBucket.time_bucket == time_bucket
        )
    ).first()

    if not bucket:
        bucket = AggregateBucket(
            h3_index=h3_index,
            time_bucket=time_bucket,
            sample_count=0,
            sum_stress=0.0,
            sum_energy=0.0,
            sum_stress_sq=0.0,
            sum_energy_sq=0.0
        )
        db.add(bucket)

    # Update running statistics
    bucket.sample_count += 1
    bucket.sum_stress += stress
    bucket.sum_energy += energy
    bucket.sum_stress_sq += stress * stress
    bucket.sum_energy_sq += energy * energy
    bucket.last_updated = datetime.utcnow()

    return bucket


def get_aggregates_for_window(
    db: Session,
    h3_indices: Optional[List[str]] = None,
    window_hours: float = 1.0
) -> List[AggregateTileOut]:
    """Get aggregated tiles for a time window, respecting k-anonymity."""
    cutoff = datetime.utcnow() - timedelta(hours=window_hours)

    query = db.query(AggregateBucket).filter(
        AggregateBucket.time_bucket >= cutoff,
        AggregateBucket.sample_count >= K_ANONYMITY_THRESHOLD
    )

    if h3_indices:
        query = query.filter(AggregateBucket.h3_index.in_(h3_indices))

    buckets = query.all()
    tiles = []

    for bucket in buckets:
        # Calculate trend by comparing to previous bucket
        prev_bucket = db.query(AggregateBucket).filter(
            and_(
                AggregateBucket.h3_index == bucket.h3_index,
                AggregateBucket.time_bucket == bucket.time_bucket - timedelta(minutes=BUCKET_SIZE_MINUTES)
            )
        ).first()

        trend = calculate_trend(bucket, prev_bucket)

        # Calculate confidence based on sample count
        confidence = min(bucket.sample_count / 100.0, 1.0)

        tiles.append(AggregateTileOut(
            h3_index=bucket.h3_index,
            time_bucket=bucket.time_bucket,
            sample_count=bucket.sample_count,
            mean_stress=bucket.mean_stress,
            mean_energy=bucket.mean_energy,
            variance=(bucket.variance_stress + bucket.variance_energy) / 2,
            trend=trend,
            confidence=confidence
        ))

    return tiles


def calculate_trend(
    current: AggregateBucket,
    previous: Optional[AggregateBucket]
) -> TrendDirection:
    """Calculate trend direction from previous bucket."""
    if not previous or previous.sample_count < K_ANONYMITY_THRESHOLD:
        return TrendDirection.stable

    # Use combined metric for trend
    current_metric = (current.mean_stress + current.mean_energy) / 2
    prev_metric = (previous.mean_stress + previous.mean_energy) / 2

    diff = current_metric - prev_metric
    threshold = 0.05  # 5% change threshold

    if diff > threshold:
        return TrendDirection.rising
    elif diff < -threshold:
        return TrendDirection.falling
    return TrendDirection.stable
