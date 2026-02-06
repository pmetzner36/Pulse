from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import json
from pathlib import Path
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.config import get_settings
from app.db.database import init_db, async_session_maker, migrate_subground_messages
from app.db.models import City
from app.api.routes import auth, users, cities, chat, mood, subgrounds

settings = get_settings()


async def seed_cities():
    """Seed cities from JSON file if not already seeded."""
    async with async_session_maker() as db:
        from sqlalchemy import select
        result = await db.execute(select(City).limit(1))
        if result.scalar_one_or_none():
            return  # Already seeded
        
        # Load cities from JSON
        cities_file = Path(__file__).parent.parent / "data" / "cities_seed.json"
        if cities_file.exists():
            with open(cities_file) as f:
                cities_data = json.load(f)
            
            for city_data in cities_data:
                city = City(**city_data)
                db.add(city)
            
            await db.commit()
            print(f"Seeded {len(cities_data)} cities")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    await migrate_subground_messages()
    await seed_cities()
    yield
    # Shutdown


limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware
origins = settings.allowed_origins.split(",") if settings.allowed_origins != "*" else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# Redirect HTTP to HTTPS in production
if not settings.debug:
    from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
    # Only add if behind a reverse proxy that sets X-Forwarded-Proto
    # app.add_middleware(HTTPSRedirectMiddleware)

# Include routers
app.include_router(auth.router, prefix="/v1")
app.include_router(users.router, prefix="/v1")
app.include_router(cities.router, prefix="/v1")
app.include_router(chat.router, prefix="/v1")
app.include_router(mood.router, prefix="/v1")
app.include_router(subgrounds.router, prefix="/v1")


@app.get("/")
async def root():
    return {"message": "PULSE API", "version": "1.0.0"}


@app.get("/health")
async def health():
    return {"status": "healthy"}
