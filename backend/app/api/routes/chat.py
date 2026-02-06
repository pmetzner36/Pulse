from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional, Dict, Set, List
from datetime import datetime
import json

from app.db.database import get_db, async_session_maker
from app.db.models import User, City, ChatMessage
from app.schemas import (
    SendMessageRequest, ChatMessageResponse, MessagesResponse,
    ChatRoomInfo, ChatCategoryInfo, VALID_CHAT_CATEGORIES
)
from app.services.auth import get_current_user, verify_access_token
from app.services.moderation import moderate_content

router = APIRouter(prefix="/chat", tags=["chat"])

# Category display info
CATEGORY_INFO = {
    "general": {"display_name": "General", "icon": "bubble.left.and.bubble.right.fill"},
    "political": {"display_name": "Political", "icon": "building.columns.fill"},
    "social": {"display_name": "Social", "icon": "person.3.fill"},
    "travel": {"display_name": "Travel", "icon": "airplane"},
    "work": {"display_name": "Work", "icon": "briefcase.fill"},
    "weather": {"display_name": "Weather", "icon": "cloud.sun.fill"},
    "health": {"display_name": "Health", "icon": "heart.fill"},
    "economy": {"display_name": "Economy", "icon": "chart.line.uptrend.xyaxis"},
    "safety": {"display_name": "Safety", "icon": "shield.fill"},
}


# WebSocket connection manager - now tracks by city_id + category
class ConnectionManager:
    def __init__(self):
        # key = "city_id:category" -> set of websocket connections
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    def _key(self, city_id: str, category: str) -> str:
        return f"{city_id}:{category}"

    async def connect(self, websocket: WebSocket, city_id: str, category: str):
        await websocket.accept()
        key = self._key(city_id, category)
        if key not in self.active_connections:
            self.active_connections[key] = set()
        self.active_connections[key].add(websocket)

    def disconnect(self, websocket: WebSocket, city_id: str, category: str):
        key = self._key(city_id, category)
        if key in self.active_connections:
            self.active_connections[key].discard(websocket)
            if not self.active_connections[key]:
                del self.active_connections[key]

    async def broadcast(self, city_id: str, category: str, message: dict):
        key = self._key(city_id, category)
        if key in self.active_connections:
            dead_connections = set()
            for connection in self.active_connections[key]:
                try:
                    await connection.send_json(message)
                except:
                    dead_connections.add(connection)
            for conn in dead_connections:
                self.active_connections[key].discard(conn)

    def get_active_count(self, city_id: str, category: str) -> int:
        key = self._key(city_id, category)
        return len(self.active_connections.get(key, set()))


manager = ConnectionManager()


@router.get("/{city_id}/categories", response_model=List[ChatCategoryInfo])
async def get_chat_categories(
    city_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get available chat categories for a city with message counts."""
    # Verify city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    categories = []
    for cat_id, cat_info in CATEGORY_INFO.items():
        # Count messages in this category
        result = await db.execute(
            select(func.count(ChatMessage.id))
            .where(ChatMessage.city_id == city_id)
            .where(ChatMessage.category == cat_id)
        )
        message_count = result.scalar() or 0

        categories.append(ChatCategoryInfo(
            category=cat_id,
            display_name=cat_info["display_name"],
            icon=cat_info["icon"],
            message_count=message_count,
            active_now=manager.get_active_count(city_id, cat_id)
        ))

    return categories


@router.get("/{city_id}/messages", response_model=MessagesResponse)
async def get_messages(
    city_id: str,
    category: str = Query(default="general"),
    limit: int = Query(default=50, le=100),
    cursor: Optional[str] = None,
    since: Optional[datetime] = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get messages for a city chat room in a specific category."""
    # Validate category
    if category not in VALID_CHAT_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    # Verify city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    # Build query
    query = select(ChatMessage).where(
        ChatMessage.city_id == city_id,
        ChatMessage.category == category
    )

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            query = query.where(ChatMessage.timestamp < cursor_time)
        except:
            pass

    if since:
        query = query.where(ChatMessage.timestamp > since)

    query = query.order_by(ChatMessage.timestamp.desc()).limit(limit + 1)

    result = await db.execute(query)
    messages = result.scalars().all()

    has_more = len(messages) > limit
    if has_more:
        messages = messages[:limit]

    # Get usernames
    user_ids = list(set(m.user_id for m in messages))
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u.username or "user" for u in users_result.scalars().all()}
    else:
        users_map = {}

    response_messages = [
        ChatMessageResponse(
            id=m.id,
            city_id=m.city_id,
            user_id=m.user_id,
            username=users_map.get(m.user_id, "user"),
            category=m.category,
            content=m.content,
            timestamp=m.timestamp
        )
        for m in messages
    ]

    next_cursor = None
    if has_more and messages:
        next_cursor = messages[-1].timestamp.isoformat()

    return MessagesResponse(
        messages=response_messages,
        has_more=has_more,
        next_cursor=next_cursor
    )


@router.post("/{city_id}/messages", response_model=ChatMessageResponse)
async def send_message(
    city_id: str,
    request: SendMessageRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Send a message to a city chat room."""
    # Validate category
    category = request.category.lower()
    if category not in VALID_CHAT_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    # Verify city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    # Moderate content before posting
    print(f"[CHAT] About to moderate: {request.content}")
    moderation_result = await moderate_content(request.content)
    print(f"[CHAT] Moderation result: flagged={moderation_result.flagged}")
    if moderation_result.flagged:
        raise HTTPException(
            status_code=400,
            detail=f"Message not allowed: {moderation_result.reason}"
        )

    # Create message
    message = ChatMessage(
        city_id=city_id,
        user_id=user.id,
        category=category,
        content=request.content.strip()
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)

    response = ChatMessageResponse(
        id=message.id,
        city_id=message.city_id,
        user_id=message.user_id,
        username=user.username or "user",
        category=message.category,
        content=message.content,
        timestamp=message.timestamp
    )

    # Broadcast to WebSocket connections in this category
    await manager.broadcast(city_id, category, {
        "type": "message",
        "payload": {
            "message": response.model_dump(mode="json")
        }
    })

    return response


@router.get("/{city_id}/info", response_model=ChatRoomInfo)
async def get_room_info(
    city_id: str,
    category: str = Query(default="general"),
    db: AsyncSession = Depends(get_db)
):
    """Get chat room info for a specific category."""
    # Validate category
    if category not in VALID_CHAT_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    # Get city
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    # Count unique users who have sent messages in this category
    result = await db.execute(
        select(func.count(func.distinct(ChatMessage.user_id)))
        .where(ChatMessage.city_id == city_id)
        .where(ChatMessage.category == category)
    )
    member_count = result.scalar() or 0

    return ChatRoomInfo(
        city_id=city_id,
        city_name=city.name,
        category=category,
        member_count=member_count,
        active_now=manager.get_active_count(city_id, category)
    )


@router.websocket("/{city_id}/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    city_id: str,
    token: str = Query(...),
    category: str = Query(default="general")
):
    """WebSocket endpoint for real-time chat in a specific category."""
    # Validate category
    if category not in VALID_CHAT_CATEGORIES:
        await websocket.close(code=4000, reason="Invalid category")
        return

    # Verify token
    user_id = verify_access_token(token)
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # Verify city exists and get user
    async with async_session_maker() as db:
        result = await db.execute(select(City).where(City.id == city_id))
        city = result.scalar_one_or_none()
        if not city:
            await websocket.close(code=4004, reason="City not found")
            return

        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            await websocket.close(code=4001, reason="User not found")
            return

        username = user.username or "user"

    await manager.connect(websocket, city_id, category)

    # Notify others of join
    await manager.broadcast(city_id, category, {
        "type": "joined",
        "payload": {
            "user_id": user_id,
            "username": username,
            "category": category
        }
    })

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                if msg.get("type") == "typing":
                    await manager.broadcast(city_id, category, {
                        "type": "typing",
                        "payload": {
                            "user_id": user_id,
                            "username": username,
                            "category": category
                        }
                    })
            except:
                pass
    except WebSocketDisconnect:
        manager.disconnect(websocket, city_id, category)
        await manager.broadcast(city_id, category, {
            "type": "left",
            "payload": {
                "user_id": user_id,
                "username": username,
                "category": category
            }
        })
