from enum import Enum
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List


# Auth schemas
class AppleSignInRequest(BaseModel):
    identity_token: str
    authorization_code: str
    full_name: Optional[str] = None
    email: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class AuthResponse(BaseModel):
    user: "UserResponse"
    access_token: str
    refresh_token: str
    expires_in: int


# User schemas
class UserResponse(BaseModel):
    id: str
    apple_user_id: str
    username: str
    email: Optional[str] = None
    created_at: datetime
    home_city: Optional[str] = None

    class Config:
        from_attributes = True


class UsernameUpdateRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=20, pattern=r"^[a-zA-Z0-9_]+$")


class UsernameCheckResponse(BaseModel):
    available: bool
    suggestion: Optional[str] = None


class UserUpdateRequest(BaseModel):
    home_city: Optional[str] = None


# City schemas
class CityResponse(BaseModel):
    id: str
    name: str
    state: str
    state_full_name: str
    latitude: float
    longitude: float
    population: int
    timezone: str

    class Config:
        from_attributes = True


# Chat schemas
VALID_CHAT_CATEGORIES = ["general", "political", "social", "travel", "work", "weather", "health", "economy", "safety"]


class SendMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)
    category: str = "general"


class ChatMessageResponse(BaseModel):
    id: str
    city_id: str
    user_id: str
    username: str
    category: str
    content: str
    timestamp: datetime

    class Config:
        from_attributes = True


class MessagesResponse(BaseModel):
    messages: List[ChatMessageResponse]
    has_more: bool
    next_cursor: Optional[str] = None


class ChatRoomInfo(BaseModel):
    city_id: str
    city_name: str
    category: str
    member_count: int
    active_now: int


class ChatCategoryInfo(BaseModel):
    category: str
    display_name: str
    icon: str
    message_count: int
    active_now: int


# Subground schemas
class CreateSubgroundRequest(BaseModel):
    name: str = Field(..., min_length=3, max_length=50)
    description: Optional[str] = Field(None, max_length=200)
    emoji: Optional[str] = Field(None, max_length=10)
    category: str = "general"


class SubgroundResponse(BaseModel):
    id: str
    city_id: str
    category: str
    creator_id: str
    creator_username: str
    name: str
    description: Optional[str]
    emoji: Optional[str]
    is_active: bool
    member_count: int
    message_count: int
    created_at: datetime
    last_activity: datetime

    class Config:
        from_attributes = True


class SubgroundListResponse(BaseModel):
    subgrounds: List[SubgroundResponse]
    total: int


# Post type enum
class PostType(str, Enum):
    text = "text"
    link = "link"
    image = "image"


# Subground message schemas
class SendSubgroundMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)
    reply_to_id: Optional[str] = None


# Post-specific schemas
class CreateSubgroundPostRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = Field(None, max_length=5000)
    post_type: PostType = PostType.text
    url: Optional[str] = Field(None, max_length=2000)


class EditSubgroundPostRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = Field(None, max_length=5000)
    url: Optional[str] = Field(None, max_length=2000)


class SendSubgroundCommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)
    url: Optional[str] = Field(None, max_length=2000)


class EditSubgroundCommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)


class LinkPreviewData(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None


class ReactionResponse(BaseModel):
    emoji: str
    count: int
    users: List[str]  # List of usernames who reacted
    user_reacted: bool  # Whether current user reacted with this emoji


class SubgroundMessageResponse(BaseModel):
    id: str
    subground_id: str
    user_id: str
    username: str
    content: str
    reply_to_id: Optional[str]
    timestamp: datetime
    reactions: List[ReactionResponse] = []
    title: Optional[str] = None
    post_type: Optional[str] = None
    url: Optional[str] = None
    link_preview: Optional[LinkPreviewData] = None
    comment_count: Optional[int] = None

    class Config:
        from_attributes = True


class SubgroundMessagesResponse(BaseModel):
    messages: List[SubgroundMessageResponse]
    has_more: bool
    next_cursor: Optional[str] = None


# Reaction schemas
class AddReactionRequest(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=10)


# Update forward references
AuthResponse.model_rebuild()
