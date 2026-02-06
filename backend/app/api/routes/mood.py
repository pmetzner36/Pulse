from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from typing import List, Optional
from pydantic import BaseModel

from app.db.database import get_db
from app.db.models import User, City, MoodSubmission
from app.services.auth import get_current_user
from app.services.news_service import fetch_all_category_news

router = APIRouter(prefix="/mood", tags=["mood"])


# MARK: - Schemas

class SubmitMoodRequest(BaseModel):
    city_id: str
    categories: List[str]
    rating: int
    note: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class MoodSubmissionResponse(BaseModel):
    id: str
    user_id: str
    city_id: str
    categories: List[str]
    rating: int
    note: Optional[str]
    timestamp: datetime
    latitude: Optional[float]
    longitude: Optional[float]

    class Config:
        from_attributes = True


class CategoryMood(BaseModel):
    category: str
    average_rating: float
    count: int


class CityMoodSummary(BaseModel):
    city_id: str
    city_name: str
    overall_rating: float
    total_submissions: int
    category_breakdown: List[CategoryMood]
    last_updated: datetime


class MoodAggregateResponse(BaseModel):
    id: str
    city_id: str
    category: str
    average_rating: float
    submission_count: int
    trend: str
    latitude: float
    longitude: float


class MapMoodPinResponse(BaseModel):
    id: str
    username: str
    rating: int
    categories: List[str]
    timestamp: datetime
    latitude: float
    longitude: float


# MARK: - Endpoints

@router.post("/submit", response_model=MoodSubmissionResponse)
async def submit_mood(
    request: SubmitMoodRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Submit a mood entry."""
    # Validate rating
    if request.rating < 1 or request.rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5")

    # Validate city exists
    result = await db.execute(select(City).where(City.id == request.city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    # Validate categories
    valid_categories = ["Political", "Social", "Travel", "Work", "Weather", "Health", "Economy", "Safety"]
    for cat in request.categories:
        if cat not in valid_categories:
            raise HTTPException(status_code=400, detail=f"Invalid category: {cat}")

    # Create submission
    submission = MoodSubmission(
        user_id=user.id,
        city_id=request.city_id,
        categories=",".join(request.categories),
        rating=request.rating,
        note=request.note,
        latitude=request.latitude,
        longitude=request.longitude
    )
    db.add(submission)
    await db.commit()
    await db.refresh(submission)

    return MoodSubmissionResponse(
        id=submission.id,
        user_id=submission.user_id,
        city_id=submission.city_id,
        categories=submission.categories.split(","),
        rating=submission.rating,
        note=submission.note,
        timestamp=submission.timestamp,
        latitude=submission.latitude,
        longitude=submission.longitude
    )


@router.get("/city/{city_id}", response_model=CityMoodSummary)
async def get_city_mood(
    city_id: str,
    hours: int = 24,
    db: AsyncSession = Depends(get_db)
):
    """Get mood summary for a city."""
    # Validate city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    # Get submissions from last N hours
    since = datetime.utcnow() - timedelta(hours=hours)

    result = await db.execute(
        select(MoodSubmission)
        .where(MoodSubmission.city_id == city_id)
        .where(MoodSubmission.timestamp >= since)
    )
    submissions = result.scalars().all()

    if not submissions:
        return CityMoodSummary(
            city_id=city_id,
            city_name=city.name,
            overall_rating=3.0,
            total_submissions=0,
            category_breakdown=[],
            last_updated=datetime.utcnow()
        )

    # Calculate overall rating
    total_rating = sum(s.rating for s in submissions)
    overall_rating = total_rating / len(submissions)

    # Calculate category breakdown
    category_data = {}
    for submission in submissions:
        for cat in submission.categories.split(","):
            if cat not in category_data:
                category_data[cat] = {"total": 0, "count": 0}
            category_data[cat]["total"] += submission.rating
            category_data[cat]["count"] += 1

    category_breakdown = [
        CategoryMood(
            category=cat,
            average_rating=data["total"] / data["count"],
            count=data["count"]
        )
        for cat, data in category_data.items()
    ]

    # Sort by count
    category_breakdown.sort(key=lambda x: x.count, reverse=True)

    return CityMoodSummary(
        city_id=city_id,
        city_name=city.name,
        overall_rating=overall_rating,
        total_submissions=len(submissions),
        category_breakdown=category_breakdown,
        last_updated=max(s.timestamp for s in submissions)
    )


@router.get("/aggregates/{city_id}", response_model=List[MoodAggregateResponse])
async def get_mood_aggregates(
    city_id: str,
    category: Optional[str] = None,
    hours: int = 24,
    db: AsyncSession = Depends(get_db)
):
    """Get aggregated mood data for map display."""
    # Validate city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    since = datetime.utcnow() - timedelta(hours=hours)

    # Query submissions
    query = select(MoodSubmission).where(
        MoodSubmission.city_id == city_id,
        MoodSubmission.timestamp >= since
    )

    result = await db.execute(query)
    submissions = result.scalars().all()

    # Aggregate by category
    category_aggregates = {}
    valid_categories = ["Political", "Social", "Travel", "Work", "Weather", "Health", "Economy", "Safety"]

    for cat in valid_categories:
        if category and cat != category:
            continue

        cat_submissions = [s for s in submissions if cat in s.categories.split(",")]

        if cat_submissions:
            avg_rating = sum(s.rating for s in cat_submissions) / len(cat_submissions)

            # Calculate trend (compare to older submissions)
            older_since = since - timedelta(hours=hours)
            older_result = await db.execute(
                select(MoodSubmission).where(
                    MoodSubmission.city_id == city_id,
                    MoodSubmission.timestamp >= older_since,
                    MoodSubmission.timestamp < since
                )
            )
            older_submissions = [s for s in older_result.scalars().all() if cat in s.categories.split(",")]

            if older_submissions:
                older_avg = sum(s.rating for s in older_submissions) / len(older_submissions)
                if avg_rating > older_avg + 0.2:
                    trend = "rising"
                elif avg_rating < older_avg - 0.2:
                    trend = "falling"
                else:
                    trend = "stable"
            else:
                trend = "stable"

            category_aggregates[cat] = MoodAggregateResponse(
                id=f"{city_id}-{cat.lower()}",
                city_id=city_id,
                category=cat,
                average_rating=avg_rating,
                submission_count=len(cat_submissions),
                trend=trend,
                latitude=city.latitude,
                longitude=city.longitude
            )

    return list(category_aggregates.values())


@router.get("/map/{city_id}", response_model=List[MapMoodPinResponse])
async def get_mood_map_pins(
    city_id: str,
    minutes: int = 1440,
    db: AsyncSession = Depends(get_db)
):
    """Get recent mood submissions with location for map display."""
    # Validate city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    since = datetime.utcnow() - timedelta(minutes=minutes)

    result = await db.execute(
        select(MoodSubmission)
        .where(
            MoodSubmission.city_id == city_id,
            MoodSubmission.timestamp >= since,
            MoodSubmission.latitude.isnot(None),
            MoodSubmission.longitude.isnot(None),
        )
        .order_by(MoodSubmission.timestamp.desc())
        .limit(200)
    )
    submissions = result.scalars().all()

    # Batch-load usernames to avoid N+1 queries
    user_ids = list(set(s.user_id for s in submissions))
    if user_ids:
        user_result = await db.execute(
            select(User).where(User.id.in_(user_ids))
        )
        users_by_id = {u.id: u for u in user_result.scalars().all()}
    else:
        users_by_id = {}

    pins = []
    for s in submissions:
        user = users_by_id.get(s.user_id)
        if user and user.username:
            anon_name = user.username[0] + "***"
        else:
            anon_name = "a***"

        pins.append(MapMoodPinResponse(
            id=s.id,
            username=anon_name,
            rating=s.rating,
            categories=s.categories.split(","),
            timestamp=s.timestamp,
            latitude=s.latitude,
            longitude=s.longitude,
        ))

    return pins


@router.get("/my-submissions", response_model=List[MoodSubmissionResponse])
async def get_my_submissions(
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current user's mood submissions."""
    result = await db.execute(
        select(MoodSubmission)
        .where(MoodSubmission.user_id == user.id)
        .order_by(MoodSubmission.timestamp.desc())
        .limit(limit)
    )
    submissions = result.scalars().all()

    return [
        MoodSubmissionResponse(
            id=s.id,
            user_id=s.user_id,
            city_id=s.city_id,
            categories=s.categories.split(","),
            rating=s.rating,
            note=s.note,
            timestamp=s.timestamp,
            latitude=s.latitude,
            longitude=s.longitude
        )
        for s in submissions
    ]


# MARK: - News

class NewsItemResponse(BaseModel):
    title: str
    link: str
    source: str
    published: Optional[str] = None


class CategoryNewsResponse(BaseModel):
    category: str
    news: List[NewsItemResponse]


@router.get("/news/{city_id}", response_model=List[CategoryNewsResponse])
async def get_category_news(
    city_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get latest news headlines per mood category for a city."""
    # Validate city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    news_map = await fetch_all_category_news(
        city_name=city.name,
        city_id=city_id,
    )

    return [
        CategoryNewsResponse(
            category=cat,
            news=[NewsItemResponse(**item) for item in items]
        )
        for cat, items in news_map.items()
        if items  # Only include categories with news
    ]
