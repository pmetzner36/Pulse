"""Insight generation service."""

from datetime import datetime, timedelta
from typing import List, Optional
from uuid import uuid4
from sqlalchemy.orm import Session
from sqlalchemy import func

from ..db.models import AggregateBucket
from ..models.aggregate import InsightCardOut, InsightType
from .aggregation import K_ANONYMITY_THRESHOLD


def generate_insights(
    db: Session,
    city_h3_indices: List[str],
    window_hours: float = 1.0
) -> List[InsightCardOut]:
    """Generate insight cards for a city."""
    insights = []
    cutoff = datetime.utcnow() - timedelta(hours=window_hours)

    # Get current and baseline statistics
    current_stats = get_city_stats(db, city_h3_indices, cutoff)
    baseline_stats = get_city_stats(
        db, city_h3_indices,
        cutoff - timedelta(hours=24),
        cutoff - timedelta(hours=1)
    )

    if current_stats and baseline_stats:
        # Check for stress spikes
        spike_insight = detect_stress_spike(current_stats, baseline_stats)
        if spike_insight:
            insights.append(spike_insight)

        # Check for energy trends
        trend_insight = detect_energy_trend(current_stats, baseline_stats)
        if trend_insight:
            insights.append(trend_insight)

    # Regional comparison
    regional_insight = generate_regional_comparison(db, city_h3_indices, cutoff)
    if regional_insight:
        insights.append(regional_insight)

    return insights


def get_city_stats(
    db: Session,
    h3_indices: List[str],
    start_time: datetime,
    end_time: Optional[datetime] = None
) -> Optional[dict]:
    """Get aggregated statistics for a city."""
    query = db.query(
        func.sum(AggregateBucket.sample_count).label('total_samples'),
        func.sum(AggregateBucket.sum_stress).label('total_stress'),
        func.sum(AggregateBucket.sum_energy).label('total_energy'),
        func.sum(AggregateBucket.sum_stress_sq).label('total_stress_sq')
    ).filter(
        AggregateBucket.h3_index.in_(h3_indices),
        AggregateBucket.time_bucket >= start_time,
        AggregateBucket.sample_count >= K_ANONYMITY_THRESHOLD
    )

    if end_time:
        query = query.filter(AggregateBucket.time_bucket < end_time)

    result = query.first()

    if not result or not result.total_samples or result.total_samples < K_ANONYMITY_THRESHOLD:
        return None

    mean_stress = result.total_stress / result.total_samples
    mean_energy = result.total_energy / result.total_samples
    variance = (result.total_stress_sq / result.total_samples) - (mean_stress ** 2)

    return {
        'sample_count': result.total_samples,
        'mean_stress': mean_stress,
        'mean_energy': mean_energy,
        'std_stress': variance ** 0.5 if variance > 0 else 0
    }


def detect_stress_spike(current: dict, baseline: dict) -> Optional[InsightCardOut]:
    """Detect if stress is significantly higher than baseline."""
    if baseline['std_stress'] == 0:
        return None

    z_score = (current['mean_stress'] - baseline['mean_stress']) / baseline['std_stress']

    if z_score > 2.0:  # 2 standard deviations above baseline
        pct_increase = int((current['mean_stress'] / baseline['mean_stress'] - 1) * 100)
        return InsightCardOut(
            id=str(uuid4()),
            type=InsightType.spike,
            title="Stress Spike",
            description=f"Stress levels are {pct_increase}% higher than usual. This often happens during busy periods.",
            region="City-wide",
            timestamp=datetime.utcnow(),
            metric_value=current['mean_stress'],
            metric_label="Current Stress"
        )

    return None


def detect_energy_trend(current: dict, baseline: dict) -> Optional[InsightCardOut]:
    """Detect energy level trends."""
    energy_diff = current['mean_energy'] - baseline['mean_energy']

    if abs(energy_diff) > 0.1:  # 10% difference
        direction = "rising" if energy_diff > 0 else "falling"
        return InsightCardOut(
            id=str(uuid4()),
            type=InsightType.trend,
            title="City Trend",
            description=f"Energy levels have been {direction} across the city.",
            region="City-wide",
            timestamp=datetime.utcnow(),
            metric_value=current['mean_energy'],
            metric_label="Energy Level"
        )

    return None


def generate_regional_comparison(
    db: Session,
    h3_indices: List[str],
    cutoff: datetime
) -> Optional[InsightCardOut]:
    """Compare different regions within the city."""
    # Get per-region stats
    region_stats = db.query(
        AggregateBucket.h3_index,
        func.sum(AggregateBucket.sample_count).label('samples'),
        func.sum(AggregateBucket.sum_stress).label('stress'),
        func.sum(AggregateBucket.sum_energy).label('energy')
    ).filter(
        AggregateBucket.h3_index.in_(h3_indices),
        AggregateBucket.time_bucket >= cutoff,
        AggregateBucket.sample_count >= K_ANONYMITY_THRESHOLD
    ).group_by(AggregateBucket.h3_index).all()

    if len(region_stats) < 2:
        return None

    # Find calmest region
    calmest = min(region_stats, key=lambda r: r.stress / r.samples if r.samples else 1)
    if calmest.samples >= K_ANONYMITY_THRESHOLD:
        calm_stress = calmest.stress / calmest.samples
        return InsightCardOut(
            id=str(uuid4()),
            type=InsightType.comparison,
            title="Calmest Area",
            description="This area is showing the lowest stress levels right now.",
            region=f"Region {calmest.h3_index[-4:]}",
            timestamp=datetime.utcnow(),
            metric_value=calm_stress,
            metric_label="Stress Level"
        )

    return None
