from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from typing import Optional, List
from datetime import datetime

from app.db.database import get_db
from app.db.models import User, City, Subground, SubgroundMessage, MessageReaction
from app.schemas import (
    CreateSubgroundRequest, SubgroundResponse, SubgroundListResponse,
    SendSubgroundMessageRequest, SubgroundMessageResponse, SubgroundMessagesResponse,
    AddReactionRequest, ReactionResponse, VALID_CHAT_CATEGORIES,
    CreateSubgroundPostRequest, EditSubgroundPostRequest,
    SendSubgroundCommentRequest, EditSubgroundCommentRequest, LinkPreviewData
)
from app.services.auth import get_current_user
from app.services.moderation import moderate_content
from app.services.link_preview import fetch_link_preview

router = APIRouter(prefix="/subgrounds", tags=["subgrounds"])


# MARK: - Subground CRUD

@router.get("/city/{city_id}", response_model=SubgroundListResponse)
async def list_subgrounds(
    city_id: str,
    category: str = Query(default="general"),
    sort: str = Query(default="activity", regex="^(activity|newest|popular)$"),
    limit: int = Query(default=20, le=50),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """List all subgrounds in a city for a specific category."""
    # Validate category
    if category not in VALID_CHAT_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    # Verify city exists
    result = await db.execute(select(City).where(City.id == city_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="City not found")

    # Build query based on sort - filter by category
    query = select(Subground).where(
        Subground.city_id == city_id,
        Subground.category == category,
        Subground.is_active == True
    )

    if sort == "activity":
        query = query.order_by(desc(Subground.last_activity))
    elif sort == "newest":
        query = query.order_by(desc(Subground.created_at))
    elif sort == "popular":
        query = query.order_by(desc(Subground.member_count))

    # Get total count for this category
    count_result = await db.execute(
        select(func.count(Subground.id)).where(
            Subground.city_id == city_id,
            Subground.category == category,
            Subground.is_active == True
        )
    )
    total = count_result.scalar() or 0

    # Get subgrounds with pagination
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    subgrounds = result.scalars().all()

    # Get creator usernames
    creator_ids = list(set(s.creator_id for s in subgrounds))
    if creator_ids:
        users_result = await db.execute(select(User).where(User.id.in_(creator_ids)))
        users_map = {u.id: u.username or "user" for u in users_result.scalars().all()}
    else:
        users_map = {}

    response_subgrounds = [
        SubgroundResponse(
            id=s.id,
            city_id=s.city_id,
            category=s.category,
            creator_id=s.creator_id,
            creator_username=users_map.get(s.creator_id, "user"),
            name=s.name,
            description=s.description,
            emoji=s.emoji,
            is_active=s.is_active,
            member_count=s.member_count,
            message_count=s.message_count,
            created_at=s.created_at,
            last_activity=s.last_activity
        )
        for s in subgrounds
    ]

    return SubgroundListResponse(subgrounds=response_subgrounds, total=total)


@router.post("/city/{city_id}", response_model=SubgroundResponse)
async def create_subground(
    city_id: str,
    request: CreateSubgroundRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new subground in a city category."""
    print(f"[Subground] Creating subground in city: '{city_id}', category: '{request.category}'")
    print(f"[Subground] Request: name='{request.name}', emoji='{request.emoji}'")

    # Validate category
    category = request.category.lower()
    if category not in VALID_CHAT_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    # Verify city exists
    result = await db.execute(select(City).where(City.id == city_id))
    city = result.scalar_one_or_none()
    if not city:
        # Debug: list available cities
        all_cities = await db.execute(select(City.id).limit(10))
        city_ids = [c[0] for c in all_cities.fetchall()]
        print(f"[Subground] City '{city_id}' not found. Available: {city_ids}")
        raise HTTPException(status_code=404, detail=f"City not found: {city_id}")

    # Check for duplicate name in this city+category
    result = await db.execute(
        select(Subground).where(
            Subground.city_id == city_id,
            Subground.category == category,
            func.lower(Subground.name) == request.name.lower(),
            Subground.is_active == True
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A community with this name already exists in this category")

    # Moderate the name and description
    moderation = await moderate_content(f"{request.name} {request.description or ''}")
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Content not allowed: {moderation.reason}")

    # Create subground
    subground = Subground(
        city_id=city_id,
        category=category,
        creator_id=user.id,
        name=request.name.strip(),
        description=request.description.strip() if request.description else None,
        emoji=request.emoji
    )
    db.add(subground)
    await db.commit()
    await db.refresh(subground)

    return SubgroundResponse(
        id=subground.id,
        city_id=subground.city_id,
        category=subground.category,
        creator_id=subground.creator_id,
        creator_username=user.username or "user",
        name=subground.name,
        description=subground.description,
        emoji=subground.emoji,
        is_active=subground.is_active,
        member_count=subground.member_count,
        message_count=subground.message_count,
        created_at=subground.created_at,
        last_activity=subground.last_activity
    )


@router.get("/link-preview", response_model=LinkPreviewData)
async def get_link_preview(
    url: str = Query(..., min_length=1),
    user: User = Depends(get_current_user),
):
    """Fetch Open Graph preview data for a URL."""
    return await fetch_link_preview(url)


@router.get("/{subground_id}", response_model=SubgroundResponse)
async def get_subground(
    subground_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get subground details."""
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if not subground:
        raise HTTPException(status_code=404, detail="Subground not found")

    # Get creator username
    result = await db.execute(select(User).where(User.id == subground.creator_id))
    creator = result.scalar_one_or_none()

    return SubgroundResponse(
        id=subground.id,
        city_id=subground.city_id,
        category=subground.category,
        creator_id=subground.creator_id,
        creator_username=creator.username if creator else "user",
        name=subground.name,
        description=subground.description,
        emoji=subground.emoji,
        is_active=subground.is_active,
        member_count=subground.member_count,
        message_count=subground.message_count,
        created_at=subground.created_at,
        last_activity=subground.last_activity
    )


# MARK: - Subground Messages

@router.get("/{subground_id}/messages", response_model=SubgroundMessagesResponse)
async def get_subground_messages(
    subground_id: str,
    limit: int = Query(default=50, le=100),
    cursor: Optional[str] = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get messages in a subground."""
    # Verify subground exists
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if not subground:
        raise HTTPException(status_code=404, detail="Subground not found")

    # Build query
    query = select(SubgroundMessage).where(SubgroundMessage.subground_id == subground_id)

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            query = query.where(SubgroundMessage.timestamp < cursor_time)
        except:
            pass

    query = query.order_by(desc(SubgroundMessage.timestamp)).limit(limit + 1)

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

    # Get reactions for all messages
    message_ids = [m.id for m in messages]
    reactions_map = {}
    if message_ids:
        reactions_result = await db.execute(
            select(MessageReaction).where(MessageReaction.message_id.in_(message_ids))
        )
        all_reactions = reactions_result.scalars().all()

        # Get usernames for reactions
        reaction_user_ids = list(set(r.user_id for r in all_reactions))
        if reaction_user_ids:
            reaction_users_result = await db.execute(select(User).where(User.id.in_(reaction_user_ids)))
            reaction_users_map = {u.id: u.username or "user" for u in reaction_users_result.scalars().all()}
        else:
            reaction_users_map = {}

        # Group reactions by message and emoji
        for reaction in all_reactions:
            if reaction.message_id not in reactions_map:
                reactions_map[reaction.message_id] = {}
            if reaction.emoji not in reactions_map[reaction.message_id]:
                reactions_map[reaction.message_id][reaction.emoji] = {
                    "users": [],
                    "user_ids": []
                }
            reactions_map[reaction.message_id][reaction.emoji]["users"].append(
                reaction_users_map.get(reaction.user_id, "user")
            )
            reactions_map[reaction.message_id][reaction.emoji]["user_ids"].append(reaction.user_id)

    # Build response
    response_messages = []
    for m in messages:
        msg_reactions = []
        if m.id in reactions_map:
            for emoji, data in reactions_map[m.id].items():
                msg_reactions.append(ReactionResponse(
                    emoji=emoji,
                    count=len(data["users"]),
                    users=data["users"][:5],  # Limit to first 5 usernames
                    user_reacted=user.id in data["user_ids"]
                ))

        response_messages.append(SubgroundMessageResponse(
            id=m.id,
            subground_id=m.subground_id,
            user_id=m.user_id,
            username=users_map.get(m.user_id, "user"),
            content=m.content,
            reply_to_id=m.reply_to_id,
            timestamp=m.timestamp,
            reactions=msg_reactions
        ))

    # Reverse to get chronological order
    response_messages.reverse()

    next_cursor = None
    if has_more and messages:
        next_cursor = messages[-1].timestamp.isoformat()

    return SubgroundMessagesResponse(
        messages=response_messages,
        has_more=has_more,
        next_cursor=next_cursor
    )


@router.post("/{subground_id}/messages", response_model=SubgroundMessageResponse)
async def send_subground_message(
    subground_id: str,
    request: SendSubgroundMessageRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Send a message to a subground."""
    # Verify subground exists
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if not subground:
        raise HTTPException(status_code=404, detail="Subground not found")

    # Moderate content
    moderation = await moderate_content(request.content)
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Message not allowed: {moderation.reason}")

    # Verify reply_to exists if provided
    if request.reply_to_id:
        result = await db.execute(
            select(SubgroundMessage).where(
                SubgroundMessage.id == request.reply_to_id,
                SubgroundMessage.subground_id == subground_id
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="Reply target message not found")

    # Create message
    message = SubgroundMessage(
        subground_id=subground_id,
        user_id=user.id,
        content=request.content.strip(),
        reply_to_id=request.reply_to_id
    )
    db.add(message)

    # Update subground stats
    subground.message_count += 1
    subground.last_activity = datetime.utcnow()

    await db.commit()
    await db.refresh(message)

    return SubgroundMessageResponse(
        id=message.id,
        subground_id=message.subground_id,
        user_id=message.user_id,
        username=user.username or "user",
        content=message.content,
        reply_to_id=message.reply_to_id,
        timestamp=message.timestamp,
        reactions=[]
    )


# MARK: - Reactions

@router.post("/{subground_id}/messages/{message_id}/reactions", response_model=ReactionResponse)
async def add_reaction(
    subground_id: str,
    message_id: str,
    request: AddReactionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a reaction to a message."""
    # Verify message exists in this subground
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == message_id,
            SubgroundMessage.subground_id == subground_id
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Message not found")

    # Check if user already reacted with this emoji
    result = await db.execute(
        select(MessageReaction).where(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == user.id,
            MessageReaction.emoji == request.emoji
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        # Remove reaction (toggle off)
        await db.delete(existing)
        await db.commit()

        # Get updated reaction count
        result = await db.execute(
            select(MessageReaction).where(
                MessageReaction.message_id == message_id,
                MessageReaction.emoji == request.emoji
            )
        )
        remaining = result.scalars().all()

        return ReactionResponse(
            emoji=request.emoji,
            count=len(remaining),
            users=[],
            user_reacted=False
        )
    else:
        # Add new reaction
        reaction = MessageReaction(
            message_id=message_id,
            user_id=user.id,
            emoji=request.emoji
        )
        db.add(reaction)
        await db.commit()

        # Get updated reaction count
        result = await db.execute(
            select(MessageReaction).where(
                MessageReaction.message_id == message_id,
                MessageReaction.emoji == request.emoji
            )
        )
        all_reactions = result.scalars().all()

        # Get usernames
        user_ids = [r.user_id for r in all_reactions]
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        usernames = [u.username or "user" for u in users_result.scalars().all()]

        return ReactionResponse(
            emoji=request.emoji,
            count=len(all_reactions),
            users=usernames[:5],
            user_reacted=True
        )


@router.delete("/{subground_id}/messages/{message_id}/reactions/{emoji}")
async def remove_reaction(
    subground_id: str,
    message_id: str,
    emoji: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove a reaction from a message."""
    result = await db.execute(
        select(MessageReaction).where(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == user.id,
            MessageReaction.emoji == emoji
        )
    )
    reaction = result.scalar_one_or_none()

    if reaction:
        await db.delete(reaction)
        await db.commit()

    return {"status": "ok"}


@router.delete("/{subground_id}/posts/{post_id}")
async def delete_post(
    subground_id: str,
    post_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a post (only by its author). Also deletes all comments and reactions."""
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == post_id,
            SubgroundMessage.subground_id == subground_id,
        )
    )
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.user_id != user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own posts")

    # Delete reactions on comments of this post
    comments_result = await db.execute(
        select(SubgroundMessage.id).where(SubgroundMessage.reply_to_id == post_id)
    )
    comment_ids = [row[0] for row in comments_result.fetchall()]
    if comment_ids:
        await db.execute(
            MessageReaction.__table__.delete().where(
                MessageReaction.message_id.in_(comment_ids)
            )
        )
        # Delete comments
        await db.execute(
            SubgroundMessage.__table__.delete().where(
                SubgroundMessage.id.in_(comment_ids)
            )
        )

    # Delete reactions on the post itself
    await db.execute(
        MessageReaction.__table__.delete().where(
            MessageReaction.message_id == post_id
        )
    )

    # Update subground stats
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if subground:
        deleted_count = 1 + len(comment_ids)
        subground.message_count = max(0, subground.message_count - deleted_count)

    # Delete the post
    await db.delete(post)
    await db.commit()

    return {"status": "ok"}


# MARK: - Posts (Reddit-style)

async def _build_message_response(
    message: SubgroundMessage,
    username: str,
    user_id: str,
    reactions_map: dict,
    comment_count: Optional[int] = None,
) -> SubgroundMessageResponse:
    """Build a SubgroundMessageResponse with post fields."""
    msg_reactions = []
    if message.id in reactions_map:
        for emoji, data in reactions_map[message.id].items():
            msg_reactions.append(ReactionResponse(
                emoji=emoji,
                count=len(data["users"]),
                users=data["users"][:5],
                user_reacted=user_id in data["user_ids"]
            ))

    link_preview = None
    if message.link_preview_title or message.link_preview_description or message.link_preview_image:
        link_preview = LinkPreviewData(
            title=message.link_preview_title,
            description=message.link_preview_description,
            image_url=message.link_preview_image,
        )

    return SubgroundMessageResponse(
        id=message.id,
        subground_id=message.subground_id,
        user_id=message.user_id,
        username=username,
        content=message.content,
        reply_to_id=message.reply_to_id,
        timestamp=message.timestamp,
        reactions=msg_reactions,
        title=message.title,
        post_type=message.post_type,
        url=message.url,
        link_preview=link_preview,
        comment_count=comment_count,
    )


async def _get_reactions_map(db: AsyncSession, message_ids: List[str]) -> dict:
    """Fetch and group reactions for a list of message IDs."""
    reactions_map: dict = {}
    if not message_ids:
        return reactions_map

    reactions_result = await db.execute(
        select(MessageReaction).where(MessageReaction.message_id.in_(message_ids))
    )
    all_reactions = reactions_result.scalars().all()

    reaction_user_ids = list(set(r.user_id for r in all_reactions))
    reaction_users_map: dict = {}
    if reaction_user_ids:
        reaction_users_result = await db.execute(select(User).where(User.id.in_(reaction_user_ids)))
        reaction_users_map = {u.id: u.username or "user" for u in reaction_users_result.scalars().all()}

    for reaction in all_reactions:
        if reaction.message_id not in reactions_map:
            reactions_map[reaction.message_id] = {}
        if reaction.emoji not in reactions_map[reaction.message_id]:
            reactions_map[reaction.message_id][reaction.emoji] = {"users": [], "user_ids": []}
        reactions_map[reaction.message_id][reaction.emoji]["users"].append(
            reaction_users_map.get(reaction.user_id, "user")
        )
        reactions_map[reaction.message_id][reaction.emoji]["user_ids"].append(reaction.user_id)

    return reactions_map


@router.post("/{subground_id}/posts", response_model=SubgroundMessageResponse)
async def create_post(
    subground_id: str,
    request: CreateSubgroundPostRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Create a new post in a subground."""
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if not subground:
        raise HTTPException(status_code=404, detail="Subground not found")

    # Require at least content or url
    if not (request.content and request.content.strip()) and not (request.url and request.url.strip()):
        raise HTTPException(status_code=400, detail="Post must have content or a URL")

    # Moderate content
    text_to_moderate = f"{request.title or ''} {request.content or ''}"
    moderation = await moderate_content(text_to_moderate)
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Content not allowed: {moderation.reason}")

    # Fetch link preview for link posts
    lp_title = lp_desc = lp_image = None
    if request.post_type == "link" and request.url:
        preview = await fetch_link_preview(request.url)
        lp_title = preview.title
        lp_desc = preview.description
        lp_image = preview.image_url

    message = SubgroundMessage(
        subground_id=subground_id,
        user_id=user.id,
        content=(request.content or "").strip(),
        title=request.title.strip() if request.title else None,
        post_type=request.post_type.value,
        url=request.url,
        link_preview_title=lp_title,
        link_preview_description=lp_desc,
        link_preview_image=lp_image,
    )
    db.add(message)

    subground.message_count += 1
    subground.last_activity = datetime.utcnow()

    await db.commit()
    await db.refresh(message)

    return await _build_message_response(
        message, user.username or "user", user.id, {}, comment_count=0
    )


@router.get("/{subground_id}/posts", response_model=SubgroundMessagesResponse)
async def list_posts(
    subground_id: str,
    sort: str = Query(default="newest", pattern="^(newest|most_reactions)$"),
    limit: int = Query(default=20, le=50),
    cursor: Optional[str] = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List top-level posts in a subground (reply_to_id IS NULL and title IS NOT NULL)."""
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Subground not found")

    query = select(SubgroundMessage).where(
        SubgroundMessage.subground_id == subground_id,
        SubgroundMessage.reply_to_id.is_(None),
        SubgroundMessage.post_type.isnot(None),
    )

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            query = query.where(SubgroundMessage.timestamp < cursor_time)
        except Exception:
            pass

    if sort == "newest":
        query = query.order_by(desc(SubgroundMessage.timestamp))
    else:
        # most_reactions: subquery count
        reaction_count = (
            select(func.count(MessageReaction.id))
            .where(MessageReaction.message_id == SubgroundMessage.id)
            .correlate(SubgroundMessage)
            .scalar_subquery()
        )
        query = query.order_by(desc(reaction_count), desc(SubgroundMessage.timestamp))

    query = query.limit(limit + 1)
    result = await db.execute(query)
    posts = result.scalars().all()

    has_more = len(posts) > limit
    if has_more:
        posts = posts[:limit]

    # Usernames
    user_ids = list(set(p.user_id for p in posts))
    users_map: dict = {}
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u.username or "user" for u in users_result.scalars().all()}

    post_ids = [p.id for p in posts]
    reactions_map = await _get_reactions_map(db, post_ids)

    # Comment counts per post
    comment_counts: dict = {}
    if post_ids:
        count_result = await db.execute(
            select(SubgroundMessage.reply_to_id, func.count(SubgroundMessage.id))
            .where(SubgroundMessage.reply_to_id.in_(post_ids))
            .group_by(SubgroundMessage.reply_to_id)
        )
        comment_counts = {row[0]: row[1] for row in count_result.fetchall()}

    response_posts = []
    for p in posts:
        resp = await _build_message_response(
            p,
            users_map.get(p.user_id, "user"),
            user.id,
            reactions_map,
            comment_count=comment_counts.get(p.id, 0),
        )
        response_posts.append(resp)

    next_cursor = None
    if has_more and posts:
        next_cursor = posts[-1].timestamp.isoformat()

    return SubgroundMessagesResponse(
        messages=response_posts,
        has_more=has_more,
        next_cursor=next_cursor,
    )


@router.get("/{subground_id}/posts/{post_id}/comments", response_model=SubgroundMessagesResponse)
async def get_post_comments(
    subground_id: str,
    post_id: str,
    limit: int = Query(default=50, le=100),
    cursor: Optional[str] = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get comments for a specific post."""
    # Verify post exists
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == post_id,
            SubgroundMessage.subground_id == subground_id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Post not found")

    query = select(SubgroundMessage).where(
        SubgroundMessage.reply_to_id == post_id,
        SubgroundMessage.subground_id == subground_id,
    )

    if cursor:
        try:
            cursor_time = datetime.fromisoformat(cursor)
            query = query.where(SubgroundMessage.timestamp < cursor_time)
        except Exception:
            pass

    query = query.order_by(SubgroundMessage.timestamp).limit(limit + 1)
    result = await db.execute(query)
    comments = result.scalars().all()

    has_more = len(comments) > limit
    if has_more:
        comments = comments[:limit]

    user_ids = list(set(c.user_id for c in comments))
    users_map: dict = {}
    if user_ids:
        users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
        users_map = {u.id: u.username or "user" for u in users_result.scalars().all()}

    comment_ids = [c.id for c in comments]
    reactions_map = await _get_reactions_map(db, comment_ids)

    response_comments = []
    for c in comments:
        resp = await _build_message_response(
            c, users_map.get(c.user_id, "user"), user.id, reactions_map
        )
        response_comments.append(resp)

    next_cursor = None
    if has_more and comments:
        next_cursor = comments[-1].timestamp.isoformat()

    return SubgroundMessagesResponse(
        messages=response_comments,
        has_more=has_more,
        next_cursor=next_cursor,
    )


@router.post("/{subground_id}/posts/{post_id}/comments", response_model=SubgroundMessageResponse)
async def add_comment(
    subground_id: str,
    post_id: str,
    request: SendSubgroundCommentRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a comment to a post."""
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == post_id,
            SubgroundMessage.subground_id == subground_id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Post not found")

    moderation = await moderate_content(request.content)
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Comment not allowed: {moderation.reason}")

    # Verify subground for stats update
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()

    # Fetch link preview if URL provided
    lp_title = lp_desc = lp_image = None
    if request.url:
        preview = await fetch_link_preview(request.url)
        lp_title = preview.title
        lp_desc = preview.description
        lp_image = preview.image_url

    comment = SubgroundMessage(
        subground_id=subground_id,
        user_id=user.id,
        content=request.content.strip(),
        reply_to_id=post_id,
        url=request.url,
        link_preview_title=lp_title,
        link_preview_description=lp_desc,
        link_preview_image=lp_image,
    )
    db.add(comment)

    if subground:
        subground.message_count += 1
        subground.last_activity = datetime.utcnow()

    await db.commit()
    await db.refresh(comment)

    return await _build_message_response(
        comment, user.username or "user", user.id, {}
    )


# MARK: - Edit Post

@router.put("/{subground_id}/posts/{post_id}", response_model=SubgroundMessageResponse)
async def edit_post(
    subground_id: str,
    post_id: str,
    request: EditSubgroundPostRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Edit a post (only by its author)."""
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == post_id,
            SubgroundMessage.subground_id == subground_id,
        )
    )
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    if post.user_id != user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own posts")

    # Moderate updated content
    text_to_moderate = f"{request.title or ''} {request.content or ''}"
    moderation = await moderate_content(text_to_moderate)
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Content not allowed: {moderation.reason}")

    # Update fields (only update if provided)
    if request.title is not None:
        post.title = request.title.strip() if request.title else None
    if request.content is not None:
        post.content = request.content.strip()
    if request.url is not None:
        post.url = request.url.strip() if request.url else None
        # Re-fetch link preview if URL changed
        if post.url and post.post_type == "link":
            preview = await fetch_link_preview(post.url)
            post.link_preview_title = preview.title
            post.link_preview_description = preview.description
            post.link_preview_image = preview.image_url

    await db.commit()
    await db.refresh(post)

    reactions_map = await _get_reactions_map(db, [post.id])
    return await _build_message_response(
        post, user.username or "user", user.id, reactions_map
    )


# MARK: - Delete Comment

@router.delete("/{subground_id}/posts/{post_id}/comments/{comment_id}")
async def delete_comment(
    subground_id: str,
    post_id: str,
    comment_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a comment (only by its author)."""
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == comment_id,
            SubgroundMessage.subground_id == subground_id,
            SubgroundMessage.reply_to_id == post_id,
        )
    )
    comment = result.scalar_one_or_none()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")

    if comment.user_id != user.id:
        raise HTTPException(status_code=403, detail="You can only delete your own comments")

    # Delete reactions on this comment
    await db.execute(
        MessageReaction.__table__.delete().where(
            MessageReaction.message_id == comment_id
        )
    )

    # Update subground stats
    result = await db.execute(select(Subground).where(Subground.id == subground_id))
    subground = result.scalar_one_or_none()
    if subground:
        subground.message_count = max(0, subground.message_count - 1)

    await db.delete(comment)
    await db.commit()

    return {"status": "ok"}


# MARK: - Edit Comment

@router.put("/{subground_id}/posts/{post_id}/comments/{comment_id}", response_model=SubgroundMessageResponse)
async def edit_comment(
    subground_id: str,
    post_id: str,
    comment_id: str,
    request: EditSubgroundCommentRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Edit a comment (only by its author)."""
    result = await db.execute(
        select(SubgroundMessage).where(
            SubgroundMessage.id == comment_id,
            SubgroundMessage.subground_id == subground_id,
            SubgroundMessage.reply_to_id == post_id,
        )
    )
    comment = result.scalar_one_or_none()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")

    if comment.user_id != user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own comments")

    moderation = await moderate_content(request.content)
    if moderation.flagged:
        raise HTTPException(status_code=400, detail=f"Content not allowed: {moderation.reason}")

    comment.content = request.content.strip()

    await db.commit()
    await db.refresh(comment)

    reactions_map = await _get_reactions_map(db, [comment.id])
    return await _build_message_response(
        comment, user.username or "user", user.id, reactions_map
    )
