import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import liveness_router

# Setup basic logging configuration
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.APP_NAME,
    description="Backend API for Kolomoni Liveness Verification SDK",
    version="1.0.0",
    debug=settings.DEBUG
)

# Set CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
from app.routers import auth_router
app.include_router(liveness_router.router)
app.include_router(auth_router.router)

from app.database import SessionLocal
from app.models import User
from app.auth_utils import hash_password

@app.on_event("startup")
def startup_event():
    logger.info("Initializing database session and seeding admin user...")
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.email == settings.ADMIN_EMAIL).first()
        if not admin:
            logger.info(f"Admin user not found. Seeding admin: {settings.ADMIN_EMAIL}")
            hashed_pw = hash_password(settings.ADMIN_PASSWORD)
            admin_user = User(
                email=settings.ADMIN_EMAIL,
                hashed_password=hashed_pw,
                role="admin"
            )
            db.add(admin_user)
            db.commit()
            logger.info("Admin user seeded successfully.")
        else:
            logger.info("Admin user already seeded.")
    except Exception as e:
        logger.error(f"Error seeding admin user: {e}")
    finally:
        db.close()

@app.get("/health", tags=["system"])
async def health_check():
    return {
        "status": "healthy",
        "mock_mode": settings.MOCK_AWS,
        "environment": settings.APP_ENV
    }

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting server on {settings.HOST}:{settings.PORT}")
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
