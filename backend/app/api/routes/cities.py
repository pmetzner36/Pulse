from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.db.database import get_db
from app.db.models import City
from app.schemas import CityResponse

router = APIRouter(prefix="/cities", tags=["cities"])


@router.get("", response_model=List[CityResponse])
async def list_cities(
    db: AsyncSession = Depends(get_db)
):
    """Get all available cities."""
    result = await db.execute(
        select(City).order_by(City.population.desc())
    )
    cities = result.scalars().all()
    return cities


@router.get("/{city_id}", response_model=CityResponse)
async def get_city(
    city_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific city by ID."""
    result = await db.execute(
        select(City).where(City.id == city_id)
    )
    city = result.scalar_one_or_none()
    
    if not city:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City not found"
        )
    
    return city
