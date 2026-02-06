from typing import Optional

import httpx
from bs4 import BeautifulSoup
from app.schemas import LinkPreviewData


async def fetch_link_preview(url: str) -> LinkPreviewData:
    """Fetch Open Graph metadata from a URL."""
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
            response = await client.get(url, headers={
                "User-Agent": "Mozilla/5.0 (compatible; PulseBot/1.0)"
            })
            response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")

        # Try og: tags first, then fallback to standard HTML
        og_title = _get_meta(soup, "og:title") or _get_tag_text(soup, "title")
        og_desc = _get_meta(soup, "og:description") or _get_meta(soup, "description")
        og_image = _get_meta(soup, "og:image")

        return LinkPreviewData(
            title=og_title[:500] if og_title else None,
            description=og_desc[:1000] if og_desc else None,
            image_url=og_image[:2000] if og_image else None,
        )
    except Exception:
        return LinkPreviewData()


def _get_meta(soup: BeautifulSoup, property_name: str) -> Optional[str]:
    """Get content from a meta tag by property or name."""
    tag = soup.find("meta", attrs={"property": property_name})
    if not tag:
        tag = soup.find("meta", attrs={"name": property_name})
    if tag and tag.get("content"):
        return tag["content"].strip()
    return None


def _get_tag_text(soup: BeautifulSoup, tag_name: str) -> Optional[str]:
    """Get text content of an HTML tag."""
    tag = soup.find(tag_name)
    if tag and tag.string:
        return tag.string.strip()
    return None
