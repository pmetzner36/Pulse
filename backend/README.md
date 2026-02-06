# PULSE Backend

FastAPI backend for the PULSE mood aggregation app.

## Setup

1. Create virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

### POST /v1/samples
Submit mood samples from the iOS app.

```json
{
  "samples": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "h3_index": "872830828ffffff",
      "metrics": {"stress": 0.3, "energy": 0.7},
      "signal_quality": 0.9,
      "contribution_flags": ["motion", "location"]
    }
  ],
  "device_id": "uuid",
  "app_version": "1.0.0"
}
```

### GET /v1/map
Get mood map data for a city.

Query parameters:
- `city_id`: City identifier (default: "sf")
- `window`: Time window - "15m", "1h", or "24h" (default: "1h")

### GET /v1/insights
Get mood insights for a city.

Query parameters:
- `city_id`: City identifier (default: "sf")
- `window`: Time window (default: "1h")

## Privacy

- k-anonymity threshold: 30 samples minimum per tile
- H3 resolution 7: ~5km² cells
- No individual sample data exposed
- Aggregates only returned when threshold met
