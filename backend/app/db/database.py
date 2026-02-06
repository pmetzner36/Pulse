import sqlalchemy
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import get_settings

settings = get_settings()

# Handle Railway's DATABASE_URL format (postgres:// -> postgresql+asyncpg://)
db_url = settings.database_url
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql+asyncpg://", 1)
elif db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)

engine = create_async_engine(db_url, echo=settings.debug)
async_session_maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def migrate_subground_messages():
    """Add new post columns to subground_messages table."""
    new_columns = [
        ("title", "VARCHAR(200)"),
        ("post_type", "VARCHAR(10)"),
        ("url", "VARCHAR(2000)"),
        ("link_preview_title", "VARCHAR(500)"),
        ("link_preview_description", "VARCHAR(1000)"),
        ("link_preview_image", "VARCHAR(2000)"),
    ]
    async with engine.begin() as conn:
        for col_name, col_type in new_columns:
            try:
                await conn.execute(
                    sqlalchemy.text(f"ALTER TABLE subground_messages ADD COLUMN {col_name} {col_type}")
                )
            except Exception:
                pass  # Column already exists
