from openai import AsyncOpenAI
from typing import Optional, Tuple
import os

from app.config import get_settings

print("[Moderation] Module loaded!")

# Initialize OpenAI client
# Set OPENAI_API_KEY environment variable or openai_api_key in .env
client: Optional[AsyncOpenAI] = None

def get_client() -> Optional[AsyncOpenAI]:
    global client
    settings = get_settings()
    api_key = settings.openai_api_key or os.getenv("OPENAI_API_KEY")
    print(f"[Moderation] API key present: {bool(api_key)}, length: {len(api_key) if api_key else 0}")
    if api_key and client is None:
        client = AsyncOpenAI(api_key=api_key)
        print("[Moderation] OpenAI client initialized")
    return client


class ModerationResult:
    def __init__(self, flagged: bool, reason: Optional[str] = None, categories: Optional[dict] = None):
        self.flagged = flagged
        self.reason = reason
        self.categories = categories or {}


async def moderate_content(content: str) -> ModerationResult:
    """
    Check content for harmful material using OpenAI's Moderation API.
    Returns ModerationResult with flagged=True if content violates policies.

    Categories detected:
    - hate: Content that expresses hate toward a group
    - hate/threatening: Hateful content with violence/threats
    - harassment: Content that harasses
    - harassment/threatening: Harassment with violence/threats
    - self-harm: Content about self-harm
    - sexual: Sexual content
    - sexual/minors: Sexual content involving minors
    - violence: Violent content
    - violence/graphic: Graphic violence
    """
    print(f"[Moderation] Checking content: {content[:50]}...")
    openai_client = get_client()

    # If no API key, skip moderation (for development)
    if openai_client is None:
        print("[Moderation] No client - skipping moderation")
        return ModerationResult(flagged=False)

    try:
        response = await openai_client.moderations.create(input=content)
        result = response.results[0]

        # Debug: show all category scores
        print(f"[Moderation] OpenAI flagged: {result.flagged}")
        print(f"[Moderation] Categories: {result.categories}")
        print(f"[Moderation] Scores: {result.category_scores}")

        if result.flagged:
            # Find which categories were flagged
            flagged_categories = []
            categories_dict = {}

            # Check each category
            category_names = {
                "hate": "hate speech",
                "hate/threatening": "threatening hate speech",
                "harassment": "harassment",
                "harassment/threatening": "threatening harassment",
                "self-harm": "self-harm content",
                "self-harm/intent": "self-harm intent",
                "self-harm/instructions": "self-harm instructions",
                "sexual": "sexual content",
                "sexual/minors": "content involving minors",
                "violence": "violence",
                "violence/graphic": "graphic violence",
            }

            for category, display_name in category_names.items():
                # Handle nested category names
                attr_name = category.replace("/", "_").replace("-", "_")
                if hasattr(result.categories, attr_name):
                    is_flagged = getattr(result.categories, attr_name)
                    if is_flagged:
                        flagged_categories.append(display_name)
                        categories_dict[category] = True

            reason = f"Content flagged for: {', '.join(flagged_categories)}" if flagged_categories else "Content violates community guidelines"

            print(f"[Moderation] FLAGGED: {reason}")
            return ModerationResult(
                flagged=True,
                reason=reason,
                categories=categories_dict
            )

        print("[Moderation] Content OK")
        return ModerationResult(flagged=False)

    except Exception as e:
        # If moderation API fails, use fallback filter
        print(f"Moderation error: {e}")
        print("[Moderation] Using fallback filter")
        return await moderate_content_fallback(content)


# Simple keyword-based fallback for when OpenAI is not available
BLOCKED_PATTERNS = [
    # Racial slurs
    "nigger", "nigga", "chink", "spic", "wetback", "kike", "gook", "raghead",
    "coon", "darkie", "beaner", "cracker",
    # Violence
    "kill you", "murder you", "shoot you", "stab you", "rape you",
    # Other harmful
    "kys", "kill yourself",
]

async def moderate_content_fallback(content: str) -> ModerationResult:
    """Basic keyword-based moderation as fallback."""
    content_lower = content.lower()
    print(f"[Moderation Fallback] Checking: {content_lower[:50]}...")

    for pattern in BLOCKED_PATTERNS:
        if pattern in content_lower:
            print(f"[Moderation Fallback] BLOCKED - matched: {pattern}")
            return ModerationResult(
                flagged=True,
                reason="Content violates community guidelines"
            )

    print("[Moderation Fallback] Content OK")
    return ModerationResult(flagged=False)
