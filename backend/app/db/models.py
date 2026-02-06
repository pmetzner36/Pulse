from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.db.database import Base


def generate_uuid():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=generate_uuid)
    apple_user_id = Column(String, unique=True, nullable=False, index=True)
    username = Column(String(20), unique=True, nullable=True, index=True)
    email = Column(String, nullable=True)
    full_name = Column(String, nullable=True)
    home_city = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    sessions = relationship("UserSession", back_populates="user", cascade="all, delete-orphan")
    messages = relationship("ChatMessage", back_populates="user", cascade="all, delete-orphan")


class UserSession(Base):
    __tablename__ = "user_sessions"
    
    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    refresh_token = Column(String, unique=True, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_revoked = Column(Boolean, default=False)
    
    user = relationship("User", back_populates="sessions")


class City(Base):
    __tablename__ = "cities"
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    state = Column(String(2), nullable=False)
    state_full_name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    population = Column(Integer, nullable=False)
    timezone = Column(String, nullable=False)
    
    messages = relationship("ChatMessage", back_populates="city", cascade="all, delete-orphan")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(String, primary_key=True, default=generate_uuid)
    city_id = Column(String, ForeignKey("cities.id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    category = Column(String, nullable=False, default="general", index=True)  # general, political, social, etc.
    content = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    city = relationship("City", back_populates="messages")
    user = relationship("User", back_populates="messages")


class MoodSubmission(Base):
    __tablename__ = "mood_submissions"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    city_id = Column(String, ForeignKey("cities.id"), nullable=False, index=True)
    categories = Column(String, nullable=False)  # Comma-separated list
    rating = Column(Integer, nullable=False)  # 1-5
    note = Column(Text, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User")
    city = relationship("City")


class Subground(Base):
    """User-created community topics within a city and category."""
    __tablename__ = "subgrounds"

    id = Column(String, primary_key=True, default=generate_uuid)
    city_id = Column(String, ForeignKey("cities.id"), nullable=False, index=True)
    category = Column(String, nullable=False, default="general", index=True)  # political, social, weather, etc.
    creator_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String(50), nullable=False)
    description = Column(String(200), nullable=True)
    emoji = Column(String(10), nullable=True)  # Optional emoji icon
    is_active = Column(Boolean, default=True)
    member_count = Column(Integer, default=1)
    message_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_activity = Column(DateTime, default=datetime.utcnow)

    city = relationship("City")
    creator = relationship("User")
    messages = relationship("SubgroundMessage", back_populates="subground", cascade="all, delete-orphan")


class SubgroundMessage(Base):
    """Messages/posts within a subground community."""
    __tablename__ = "subground_messages"

    id = Column(String, primary_key=True, default=generate_uuid)
    subground_id = Column(String, ForeignKey("subgrounds.id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    reply_to_id = Column(String, ForeignKey("subground_messages.id"), nullable=True)  # For threaded replies
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    # Post fields (nullable for backward compatibility with old messages)
    title = Column(String(200), nullable=True)
    post_type = Column(String(10), nullable=True)  # "text", "link", or "image"
    url = Column(String(2000), nullable=True)
    link_preview_title = Column(String(500), nullable=True)
    link_preview_description = Column(String(1000), nullable=True)
    link_preview_image = Column(String(2000), nullable=True)

    subground = relationship("Subground", back_populates="messages")
    user = relationship("User")
    reply_to = relationship("SubgroundMessage", remote_side=[id])
    reactions = relationship("MessageReaction", back_populates="message", cascade="all, delete-orphan")


class MessageReaction(Base):
    """Emoji reactions on messages."""
    __tablename__ = "message_reactions"

    id = Column(String, primary_key=True, default=generate_uuid)
    message_id = Column(String, ForeignKey("subground_messages.id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    emoji = Column(String(10), nullable=False)  # The emoji reaction
    created_at = Column(DateTime, default=datetime.utcnow)

    message = relationship("SubgroundMessage", back_populates="reactions")
    user = relationship("User")
