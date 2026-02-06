#!/usr/bin/env python3
"""Local development server. For production, use the Dockerfile."""
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True  # Dev only — Dockerfile uses production settings
    )
