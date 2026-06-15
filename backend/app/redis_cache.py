import redis
import logging
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)

# Lazy init redis client
_redis_client = None

def get_redis_client() -> Optional[redis.Redis]:
    global _redis_client
    if _redis_client is None:
        try:
            _redis_client = redis.from_url(settings.REDIS_URL, socket_timeout=1.0)
        except Exception as e:
            logger.warning(f"Failed to initialize Redis client: {e}")
            _redis_client = None
    return _redis_client

def check_cache_api_key(key_hash: str) -> Optional[bool]:
    client = get_redis_client()
    if not client:
        return None
    try:
        val = client.get(f"apikey:{key_hash}")
        if val is not None:
            return val.decode("utf-8") == "active"
    except Exception as e:
        logger.warning(f"Redis get error for {key_hash}: {e}")
        # Reset client if there's a connection issue so we try re-initializing
        global _redis_client
        _redis_client = None
    return None

def set_cache_api_key(key_hash: str, is_active: bool):
    client = get_redis_client()
    if not client:
        return
    try:
        status = "active" if is_active else "inactive"
        # Store for 1 hour (3600 seconds) for active keys, 5 mins (300 secs) for inactive keys
        ttl = 3600 if is_active else 300
        client.setex(f"apikey:{key_hash}", ttl, status)
    except Exception as e:
        logger.warning(f"Redis set error for {key_hash}: {e}")
        global _redis_client
        _redis_client = None

def clear_redis_cache():
    client = get_redis_client()
    if not client:
        return
    try:
        client.flushdb()
        logger.info("Successfully flushed Redis DB.")
    except Exception as e:
        logger.warning(f"Redis flush error: {e}")
        global _redis_client
        _redis_client = None
