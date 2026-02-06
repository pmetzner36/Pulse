"""Fetch category news headlines from Google News RSS."""

import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from typing import Optional, List, Dict
from urllib.parse import quote_plus
import asyncio
import httpx
import re
import html


CATEGORIES = ["Political", "Social", "Travel", "Work", "Weather", "Health", "Economy", "Safety"]

# In-memory cache: key = "{city_id}:{category}" -> (headlines, fetched_at)
_cache: Dict[str, tuple] = {}
CACHE_TTL = timedelta(minutes=30)

GOOGLE_NEWS_RSS = "https://news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en"

# Map our categories to better search terms
CATEGORY_SEARCH_TERMS: Dict[str, str] = {
    "Political": "politics government",
    "Social": "community social events",
    "Travel": "travel transportation",
    "Work": "jobs employment business",
    "Weather": "weather forecast",
    "Health": "health wellness",
    "Economy": "economy housing cost of living",
    "Safety": "safety crime public safety",
}


class NewsItem:
    def __init__(self, title: str, link: str, source: str, published: Optional[str] = None):
        self.title = title
        self.link = link
        self.source = source
        self.published = published

    def to_dict(self) -> dict:
        return {
            "title": self.title,
            "link": self.link,
            "source": self.source,
            "published": self.published,
        }


def _clean_html(text: str) -> str:
    """Remove HTML tags and decode entities."""
    text = html.unescape(text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.strip()


def _parse_rss(xml_text: str, limit: int = 1) -> List[NewsItem]:
    """Parse Google News RSS XML and return NewsItem list."""
    items = []
    try:
        root = ET.fromstring(xml_text)
        for item_el in root.findall(".//item"):
            if len(items) >= limit:
                break

            title_el = item_el.find("title")
            link_el = item_el.find("link")
            source_el = item_el.find("source")
            pub_el = item_el.find("pubDate")

            title = _clean_html(title_el.text) if title_el is not None and title_el.text else None
            link = link_el.text if link_el is not None and link_el.text else None
            source = source_el.text if source_el is not None and source_el.text else "Unknown"
            published = pub_el.text if pub_el is not None and pub_el.text else None

            if title and link:
                items.append(NewsItem(
                    title=title,
                    link=link,
                    source=source,
                    published=published,
                ))
    except ET.ParseError:
        pass
    return items


async def fetch_category_news(
    city_name: str,
    city_id: str,
    category: str,
    limit: int = 1,
) -> List[dict]:
    """Fetch news headlines for a city + category. Returns cached if fresh."""
    cache_key = "%s:%s" % (city_id, category)

    # Check cache
    if cache_key in _cache:
        cached_items, fetched_at = _cache[cache_key]
        if datetime.utcnow() - fetched_at < CACHE_TTL:
            return cached_items

    search_terms = CATEGORY_SEARCH_TERMS.get(category, category.lower())
    query = quote_plus("%s %s" % (city_name, search_terms))
    url = GOOGLE_NEWS_RSS.format(query=query)

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url, headers={
                "User-Agent": "Mozilla/5.0 (compatible; PulseApp/1.0)"
            })
            resp.raise_for_status()
            items = _parse_rss(resp.text, limit=limit)
            result = [item.to_dict() for item in items]
    except Exception:
        result = []

    _cache[cache_key] = (result, datetime.utcnow())
    return result


async def fetch_all_category_news(
    city_name: str,
    city_id: str,
) -> Dict[str, List[dict]]:
    """Fetch news for all categories in parallel. Returns {category: [items]}."""
    tasks = []
    for cat in CATEGORIES:
        tasks.append(fetch_category_news(city_name, city_id, cat))

    results = await asyncio.gather(*tasks, return_exceptions=True)

    news_map = {}  # type: Dict[str, List[dict]]
    for cat, result in zip(CATEGORIES, results):
        if isinstance(result, Exception):
            news_map[cat] = []
        else:
            news_map[cat] = result

    return news_map
