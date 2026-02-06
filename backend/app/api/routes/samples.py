"""API routes for mood samples."""

import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ...db.database import get_db
from ...db.models import MoodSample
from ...models.sample import SampleBatchIn, SampleBatchResponse
from ...services.aggregation import add_sample_to_bucket

router = APIRouter(prefix="/v1/samples", tags=["samples"])


@router.post("", response_model=SampleBatchResponse)
async def submit_samples(
    batch: SampleBatchIn,
    db: Session = Depends(get_db)
):
    """
    Submit a batch of mood samples.

    Samples are stored for aggregation. Individual samples are never exposed;
    only aggregates meeting k-anonymity thresholds are returned in map data.
    """
    if not batch.samples:
        raise HTTPException(status_code=400, detail="No samples provided")

    received = 0

    for sample in batch.samples:
        # Store raw sample (for debugging/audit, can be disabled in production)
        db_sample = MoodSample(
            device_id=batch.device_id,
            timestamp=sample.timestamp,
            h3_index=sample.h3_index,
            stress=sample.metrics.stress,
            energy=sample.metrics.energy,
            signal_quality=sample.signal_quality,
            contribution_flags=json.dumps(sample.contribution_flags)
        )
        db.add(db_sample)

        # Add to aggregate bucket
        add_sample_to_bucket(
            db,
            h3_index=sample.h3_index,
            timestamp=sample.timestamp,
            stress=sample.metrics.stress,
            energy=sample.metrics.energy
        )

        received += 1

    db.commit()

    return SampleBatchResponse(
        received=received,
        message=f"Successfully processed {received} samples"
    )


@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
