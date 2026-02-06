from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from app.db.database import get_db
from app.db.models import (
    User, UserSession, MoodSubmission, ChatMessage,
    SubgroundMessage, MessageReaction, Subground
)
from app.services.auth import get_current_user

router = APIRouter(prefix="/user", tags=["user"])


class DataDeletionRequest(BaseModel):
    confirm: bool = True


class DataDeletionResponse(BaseModel):
    success: bool
    message: str
    deleted_at: datetime
    samples_deleted: int


@router.delete("/data", response_model=DataDeletionResponse)
async def delete_user_data(
    request: DataDeletionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete all contributed data for the authenticated user.
    This action is irreversible.
    """
    if not request.confirm:
        raise HTTPException(
            status_code=400,
            detail="Deletion must be confirmed by setting confirm=true"
        )

    deleted_count = 0

    # Delete message reactions
    result = await db.execute(
        select(MessageReaction).where(MessageReaction.user_id == user.id)
    )
    reactions = result.scalars().all()
    for r in reactions:
        await db.delete(r)
    deleted_count += len(reactions)

    # Delete subground messages
    result = await db.execute(
        select(SubgroundMessage).where(SubgroundMessage.user_id == user.id)
    )
    messages = result.scalars().all()
    for m in messages:
        await db.delete(m)
    deleted_count += len(messages)

    # Delete chat messages
    result = await db.execute(
        select(ChatMessage).where(ChatMessage.user_id == user.id)
    )
    chats = result.scalars().all()
    for c in chats:
        await db.delete(c)
    deleted_count += len(chats)

    # Delete mood submissions
    result = await db.execute(
        select(MoodSubmission).where(MoodSubmission.user_id == user.id)
    )
    moods = result.scalars().all()
    for m in moods:
        await db.delete(m)
    deleted_count += len(moods)

    # Revoke all sessions
    result = await db.execute(
        select(UserSession).where(UserSession.user_id == user.id)
    )
    sessions = result.scalars().all()
    for s in sessions:
        await db.delete(s)

    # Delete the user account
    await db.delete(user)
    await db.commit()

    return DataDeletionResponse(
        success=True,
        message="All your data has been permanently deleted.",
        deleted_at=datetime.utcnow(),
        samples_deleted=deleted_count
    )


@router.get("/data/export")
async def export_user_data(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Export all data associated with the authenticated user (GDPR/privacy compliance).
    """
    # Mood submissions
    result = await db.execute(
        select(MoodSubmission)
        .where(MoodSubmission.user_id == user.id)
        .order_by(MoodSubmission.timestamp.desc())
    )
    moods = result.scalars().all()

    # Chat messages
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == user.id)
        .order_by(ChatMessage.timestamp.desc())
    )
    chats = result.scalars().all()

    return {
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
        "exported_at": datetime.utcnow().isoformat(),
        "mood_submissions": [
            {
                "id": m.id,
                "city_id": m.city_id,
                "categories": m.categories,
                "rating": m.rating,
                "note": m.note,
                "timestamp": m.timestamp.isoformat() if m.timestamp else None,
                "latitude": m.latitude,
                "longitude": m.longitude,
            }
            for m in moods
        ],
        "chat_messages": [
            {
                "id": c.id,
                "city_id": c.city_id,
                "category": c.category,
                "content": c.content,
                "timestamp": c.timestamp.isoformat() if c.timestamp else None,
            }
            for c in chats
        ],
        "total_mood_submissions": len(moods),
        "total_chat_messages": len(chats),
    }
