import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User, Invite
from app.auth_utils import verify_password, hash_password, create_access_token, decode_access_token

router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])
security = HTTPBearer()

# --- Request / Response Models ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    email: str
    role: str

class InviteCreateResponse(BaseModel):
    code: str
    created_by: str

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters")
    invite_code: str

class UserResponse(BaseModel):
    email: str
    role: str
    created_at: float

    class Config:
        from_attributes = True

# --- Dependency to get Current Admin User ---
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    email = payload.get("sub")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user

# --- Endpoints ---

@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    token = create_access_token(data={"sub": user.email, "role": user.role})
    return LoginResponse(
        access_token=token,
        email=user.email,
        role=user.role
    )

@router.post("/invite", response_model=InviteCreateResponse)
async def create_invite(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Generates a random, secure invitation code
    invite_code = f"INV-{uuid.uuid4().hex[:8].upper()}"
    
    invite = Invite(
        code=invite_code,
        created_by=current_user.email,
        is_used=False
    )
    db.add(invite)
    db.commit()
    
    return InviteCreateResponse(
        code=invite_code,
        created_by=current_user.email
    )

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    # 1. Validate invite code
    invite = db.query(Invite).filter(Invite.code == payload.invite_code).first()
    if not invite:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid invite code"
        )
    if invite.is_used:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invite code has already been used"
        )
        
    # 2. Check if user already exists
    existing_user = db.query(User).filter(User.email == payload.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already registered"
        )

    # 3. Create new user and mark invite as used
    hashed_pwd = hash_password(payload.password)
    new_user = User(
        email=payload.email,
        hashed_password=hashed_pwd,
        role="admin"
    )
    db.add(new_user)
    
    invite.is_used = True
    invite.used_by = payload.email
    
    db.commit()
    
    return {"message": "Admin user registered successfully"}

@router.get("/users", response_model=List[UserResponse])
async def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    users = db.query(User).order_by(User.created_at.desc()).all()
    return users
