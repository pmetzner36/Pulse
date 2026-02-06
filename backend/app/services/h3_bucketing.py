"""H3 geospatial bucketing utilities for PULSE."""

from typing import List, Tuple, Optional
import math


def lat_lng_to_h3(latitude: float, longitude: float, resolution: int = 7) -> str:
    """
    Convert latitude/longitude to an H3 index.

    This is a simplified implementation. In production, use the h3-py library:
    pip install h3
    import h3
    return h3.geo_to_h3(latitude, longitude, resolution)

    Args:
        latitude: Latitude in degrees (-90 to 90)
        longitude: Longitude in degrees (-180 to 180)
        resolution: H3 resolution (0-15, default 7 for city-block level)

    Returns:
        H3 index as a hex string
    """
    # Normalize coordinates
    lat = max(-90, min(90, latitude))
    lng = ((longitude + 180) % 360) - 180

    # Create a simple grid-based hash (simplified H3 approximation)
    # Resolution 7 gives roughly 5.16 km² hexagons
    scale = 10 ** (resolution - 4)
    lat_bucket = int((lat + 90) * scale)
    lng_bucket = int((lng + 180) * scale)

    # Create hex string similar to H3 format
    return f"8{resolution:x}{lat_bucket:06x}{lng_bucket:06x}ffffff"


def h3_to_center(h3_index: str) -> Tuple[float, float]:
    """
    Get the center coordinates of an H3 cell.

    Args:
        h3_index: H3 index string

    Returns:
        Tuple of (latitude, longitude)
    """
    try:
        # Parse our simplified format
        resolution = int(h3_index[1], 16)
        lat_bucket = int(h3_index[2:8], 16)
        lng_bucket = int(h3_index[8:14], 16)

        scale = 10 ** (resolution - 4)
        lat = (lat_bucket / scale) - 90
        lng = (lng_bucket / scale) - 180

        return (lat, lng)
    except (ValueError, IndexError):
        return (0.0, 0.0)


def get_neighbors(h3_index: str) -> List[str]:
    """
    Get the neighboring H3 cells (hexagonal ring).

    Args:
        h3_index: H3 index string

    Returns:
        List of neighboring H3 indices
    """
    try:
        center_lat, center_lng = h3_to_center(h3_index)
        resolution = int(h3_index[1], 16)

        # Approximate neighbor offsets for hexagonal grid
        # At resolution 7, cells are roughly 1.2 km across
        offset = 0.015 / (resolution - 4) if resolution > 4 else 0.015

        neighbor_offsets = [
            (offset, 0),
            (offset/2, offset * 0.866),
            (-offset/2, offset * 0.866),
            (-offset, 0),
            (-offset/2, -offset * 0.866),
            (offset/2, -offset * 0.866),
        ]

        neighbors = []
        for dlat, dlng in neighbor_offsets:
            neighbor_h3 = lat_lng_to_h3(
                center_lat + dlat,
                center_lng + dlng,
                resolution
            )
            if neighbor_h3 != h3_index:
                neighbors.append(neighbor_h3)

        return neighbors
    except (ValueError, IndexError):
        return []


def h3_distance(h3_a: str, h3_b: str) -> int:
    """
    Calculate grid distance between two H3 cells.

    Args:
        h3_a: First H3 index
        h3_b: Second H3 index

    Returns:
        Grid distance (number of cells)
    """
    try:
        lat_a, lng_a = h3_to_center(h3_a)
        lat_b, lng_b = h3_to_center(h3_b)

        # Haversine distance approximation
        R = 6371  # Earth radius in km
        dlat = math.radians(lat_b - lat_a)
        dlng = math.radians(lng_b - lng_a)

        a = math.sin(dlat/2)**2 + math.cos(math.radians(lat_a)) * \
            math.cos(math.radians(lat_b)) * math.sin(dlng/2)**2
        c = 2 * math.asin(math.sqrt(a))
        distance_km = R * c

        # Convert to grid cells (approx 1.2 km per cell at resolution 7)
        resolution = int(h3_a[1], 16) if len(h3_a) > 1 else 7
        cell_size_km = 5.0 / (2 ** (resolution - 4))

        return int(distance_km / cell_size_km)
    except (ValueError, IndexError):
        return -1


def validate_h3_index(h3_index: str) -> bool:
    """
    Validate an H3 index string.

    Args:
        h3_index: H3 index to validate

    Returns:
        True if valid, False otherwise
    """
    if not h3_index or len(h3_index) < 15:
        return False

    try:
        # Check format: 8 + resolution hex + coordinates
        if h3_index[0] != '8':
            return False
        int(h3_index[1:], 16)
        return True
    except ValueError:
        return False


# City bounding boxes for filtering (lat_min, lat_max, lng_min, lng_max)
CITY_BOUNDS = {
    "sf": (37.70, 37.85, -122.52, -122.35),
    "nyc": (40.49, 40.92, -74.26, -73.70),
    "la": (33.70, 34.34, -118.67, -118.15),
    "chicago": (41.64, 42.02, -87.94, -87.52),
    "seattle": (47.49, 47.73, -122.44, -122.24),
}


def is_in_city(h3_index: str, city_id: str) -> bool:
    """
    Check if an H3 cell is within a city's bounding box.

    Args:
        h3_index: H3 index to check
        city_id: City identifier (e.g., "sf", "nyc")

    Returns:
        True if within city bounds
    """
    if city_id not in CITY_BOUNDS:
        return True  # No bounds defined, allow all

    lat, lng = h3_to_center(h3_index)
    lat_min, lat_max, lng_min, lng_max = CITY_BOUNDS[city_id]

    return lat_min <= lat <= lat_max and lng_min <= lng <= lng_max
