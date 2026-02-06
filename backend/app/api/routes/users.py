from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import re
import random

from app.db.database import get_db
from app.db.models import User
from app.schemas import UserResponse, UsernameUpdateRequest, UsernameCheckResponse, UserUpdateRequest
from app.services.auth import get_current_user

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    user: User = Depends(get_current_user)
):
    """Get current user's profile."""
    return UserResponse(
        id=user.id,
        apple_user_id=user.apple_user_id,
        username=user.username or "",
        email=user.email,
        created_at=user.created_at,
        home_city=user.home_city
    )


@router.patch("/me", response_model=UserResponse)
async def update_current_user(
    request: UserUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update current user's profile."""
    if request.home_city is not None:
        user.home_city = request.home_city
    
    await db.commit()
    await db.refresh(user)
    
    return UserResponse(
        id=user.id,
        apple_user_id=user.apple_user_id,
        username=user.username or "",
        email=user.email,
        created_at=user.created_at,
        home_city=user.home_city
    )


@router.get("/check-username/{username}", response_model=UsernameCheckResponse)
async def check_username_availability(
    username: str,
    db: AsyncSession = Depends(get_db)
):
    """Check if a username is available."""
    # Validate format
    if not re.match(r"^[a-zA-Z0-9_]{3,20}$", username):
        return UsernameCheckResponse(available=False, suggestion=None)
    
    # Check if taken
    result = await db.execute(
        select(User).where(User.username == username.lower())
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        # Generate suggestion
        suggestion = f"{username}{random.randint(1, 999)}"
        return UsernameCheckResponse(available=False, suggestion=suggestion)
    
    return UsernameCheckResponse(available=True, suggestion=None)


@router.post("/me/username", response_model=UserResponse)
async def set_username(
    request: UsernameUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Set or update username."""
    username = request.username.lower()
    
    # Validate format
    if not re.match(r"^[a-zA-Z0-9_]{3,20}$", username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username must be 3-20 characters, alphanumeric and underscores only"
        )
    
    # Check if taken by another user
    result = await db.execute(
        select(User).where(User.username == username, User.id != user.id)
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username is already taken"
        )
    
    user.username = username
    await db.commit()
    await db.refresh(user)
    
    return UserResponse(
        id=user.id,
        apple_user_id=user.apple_user_id,
        username=user.username,
        email=user.email,
        created_at=user.created_at,
        home_city=user.home_city
    )
