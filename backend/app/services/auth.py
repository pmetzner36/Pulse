from datetime import datetime, timedelta
from typing import Optional
import secrets
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import get_settings
from app.db.database import get_db
from app.db.models import User, UserSession

settings = get_settings()
security = HTTPBearer()


def create_access_token(user_id: str) -> tuple[str, int]:
    """Create an access token. Returns (token, expires_in_seconds)."""
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
    expire = datetime.utcnow() + expires_delta
    
    to_encode = {
        "sub": user_id,
        "exp": expire,
        "type": "access"
    }
    
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, int(expires_delta.total_seconds())


def create_refresh_token() -> tuple[str, datetime]:
    """Create a refresh token. Returns (token, expires_at)."""
    token = secrets.token_urlsafe(64)
    expires_at = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)
    return token, expires_at


def verify_access_token(token: str) -> Optional[str]:
    """Verify access token and return user_id if valid."""
    try:
        payload = jwt.decode(
            token, 
            settings.jwt_secret_key, 
            algorithms=[settings.jwt_algorithm]
        )
        if payload.get("type") != "access":
            return None
        return payload.get("sub")
    except JWTError:
        return None


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Dependency to get the current authenticated user."""
    token = credentials.credentials
    user_id = verify_access_token(token)
    
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False)),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """Dependency to optionally get the current user (for endpoints that work with or without auth)."""
    if not credentials:
        return None
    
    token = credentials.credentials
    user_id = verify_access_token(token)
    
    if not user_id:
        return None
    
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
