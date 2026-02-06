from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.db.database import get_db
from app.db.models import User, UserSession
from app.schemas import AppleSignInRequest, RefreshTokenRequest, AuthResponse, UserResponse
from app.services.apple_auth import apple_auth_service
from app.services.auth import create_access_token, create_refresh_token, get_current_user

limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/apple", response_model=AuthResponse)
@limiter.limit("10/minute")
async def sign_in_with_apple(
    request: Request,
    body: AppleSignInRequest,
    db: AsyncSession = Depends(get_db)
):
    """Sign in or register with Apple."""
    # Verify the identity token with Apple
    claims = await apple_auth_service.verify_identity_token(body.identity_token)
    
    if not claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple identity token"
        )
    
    apple_user_id = claims.get("sub")
    email = body.email or claims.get("email")
    
    # Check if user exists
    result = await db.execute(
        select(User).where(User.apple_user_id == apple_user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        # Create new user
        user = User(
            apple_user_id=apple_user_id,
            email=email,
            full_name=body.full_name,
            username=""  # Will be set later
        )
        db.add(user)
        await db.flush()
    
    # Create tokens
    access_token, expires_in = create_access_token(user.id)
    refresh_token, expires_at = create_refresh_token()
    
    # Save session
    session = UserSession(
        user_id=user.id,
        refresh_token=refresh_token,
        expires_at=expires_at
    )
    db.add(session)
    await db.commit()
    await db.refresh(user)
    
    return AuthResponse(
        user=UserResponse(
            id=user.id,
            apple_user_id=user.apple_user_id,
            username=user.username or "",
            email=user.email,
            created_at=user.created_at,
            home_city=user.home_city
        ),
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in
    )


@router.post("/refresh", response_model=AuthResponse)
@limiter.limit("30/minute")
async def refresh_tokens(
    request: Request,
    body: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db)
):
    """Refresh access token using refresh token."""
    # Find the session
    result = await db.execute(
        select(UserSession).where(
            UserSession.refresh_token == body.refresh_token,
            UserSession.is_revoked == False
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    if session.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired"
        )
    
    # Get user
    result = await db.execute(select(User).where(User.id == session.user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    # Revoke old session
    session.is_revoked = True
    
    # Create new tokens
    access_token, expires_in = create_access_token(user.id)
    new_refresh_token, expires_at = create_refresh_token()
    
    # Create new session
    new_session = UserSession(
        user_id=user.id,
        refresh_token=new_refresh_token,
        expires_at=expires_at
    )
    db.add(new_session)
    await db.commit()
    
    return AuthResponse(
        user=UserResponse(
            id=user.id,
            apple_user_id=user.apple_user_id,
            username=user.username or "",
            email=user.email,
            created_at=user.created_at,
            home_city=user.home_city
        ),
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=expires_in
    )


@router.post("/logout")
async def logout(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Sign out and revoke all sessions."""
    # Revoke all user sessions
    result = await db.execute(
        select(UserSession).where(
            UserSession.user_id == user.id,
            UserSession.is_revoked == False
        )
    )
    sessions = result.scalars().all()

    for session in sessions:
        session.is_revoked = True

    await db.commit()

    return {"message": "Logged out successfully"}


@router.post("/dev-login", response_model=AuthResponse)
@limiter.limit("5/minute")
async def dev_login(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """
    Development-only endpoint to create/login a test user without Apple Sign-In.
    DO NOT use in production!
    """
    from app.config import get_settings
    if not get_settings().debug:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not found"
        )

    dev_apple_id = "dev.test.user.12345"

    # Check if dev user exists
    result = await db.execute(
        select(User).where(User.apple_user_id == dev_apple_id)
    )
    user = result.scalar_one_or_none()

    if not user:
        # Create dev user
        user = User(
            apple_user_id=dev_apple_id,
            email="dev@example.com",
            full_name="Dev User",
            username="devuser"
        )
        db.add(user)
        await db.flush()

    # Create tokens
    access_token, expires_in = create_access_token(user.id)
    refresh_token, expires_at = create_refresh_token()

    # Save session
    session = UserSession(
        user_id=user.id,
        refresh_token=refresh_token,
        expires_at=expires_at
    )
    db.add(session)
    await db.commit()
    await db.refresh(user)

    return AuthResponse(
        user=UserResponse(
            id=user.id,
            apple_user_id=user.apple_user_id,
            username=user.username or "",
            email=user.email,
            created_at=user.created_at,
            home_city=user.home_city
        ),
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in
    )
