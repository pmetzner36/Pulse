import httpx
import jwt
from jwt import PyJWKClient
from datetime import datetime, timedelta
from typing import Optional
from app.config import get_settings

settings = get_settings()

APPLE_PUBLIC_KEYS_URL = "https://appleid.apple.com/auth/keys"


class AppleAuthService:
    def __init__(self):
        self._jwks_client = PyJWKClient(APPLE_PUBLIC_KEYS_URL)
    
    async def verify_identity_token(self, identity_token: str) -> Optional[dict]:
        """
        Verify Apple identity token and return the decoded claims.
        Returns None if verification fails.
        """
        try:
            # Get the signing key from Apple's JWKS
            signing_key = self._jwks_client.get_signing_key_from_jwt(identity_token)
            
            # Decode and verify the token
            decoded = jwt.decode(
                identity_token,
                signing_key.key,
                algorithms=["RS256"],
                audience=settings.apple_client_id or None,
                issuer="https://appleid.apple.com",
                options={
                    "verify_aud": bool(settings.apple_client_id),
                    "verify_exp": True,
                }
            )
            
            return decoded
            
        except jwt.ExpiredSignatureError:
            print("Apple token expired")
            return None
        except jwt.InvalidTokenError as e:
            print(f"Invalid Apple token: {e}")
            # Only allow mock auth in debug mode
            if settings.debug and not settings.apple_client_id:
                return self._mock_verify(identity_token)
            return None
        except Exception as e:
            print(f"Error verifying Apple token: {e}")
            if settings.debug and not settings.apple_client_id:
                return self._mock_verify(identity_token)
            return None
    
    def _mock_verify(self, identity_token: str) -> dict:
        """
        Mock verification for development when Apple credentials aren't configured.
        """
        import hashlib
        # Generate a consistent mock user ID from the token
        mock_sub = hashlib.sha256(identity_token.encode()).hexdigest()[:32]
        return {
            "sub": f"mock.{mock_sub}",
            "email": f"dev.{mock_sub[:8]}@example.com",
            "email_verified": True,
        }


apple_auth_service = AppleAuthService()
