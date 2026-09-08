import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import get_db
from app.db.models import User, Dependent
from app.schemas.auth import RegisterIn, LoginIn, AnonymousIn, TokenOut, UserOut, ProfileUpdateIn
from app.services.auth import verify_password, get_password_hash, create_access_token
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterIn, db: AsyncSession = Depends(get_db)):
    # Check if user already exists
    res = await db.execute(select(User).where(User.email == req.email))
    if res.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=req.email,
        password_hash=get_password_hash(req.password),
        name=req.name,
        phone=req.phone,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    # Automatically create default 'Self' dependent profile
    dep = Dependent(
        user_id=user.id,
        name=user.name,
        relationship_type="self",
        notes="Primary profile"
    )
    db.add(dep)
    await db.flush()

    token = create_access_token(user_id=user.id, email=user.email)
    return TokenOut(token=token, user=UserOut.model_validate(user))

@router.post("/login", response_model=TokenOut)
async def login(req: LoginIn, db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(User).where(User.email == req.email))
    user = res.scalar_one_or_none()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    token = create_access_token(user_id=user.id, email=user.email)
    return TokenOut(token=token, user=UserOut.model_validate(user))

@router.post("/anonymous", response_model=TokenOut)
async def anonymous_login(req: AnonymousIn, db: AsyncSession = Depends(get_db)):
    device_id = req.device_id or uuid.uuid4().hex
    email = f"guest_{device_id}@gobi.local"

    res = await db.execute(select(User).where(User.email == email))
    user = res.scalar_one_or_none()

    if not user:
        user = User(
            email=email,
            password_hash=get_password_hash(uuid.uuid4().hex),
            name=req.name or "Guest User",
            phone=None,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)

        # Create default 'Self' dependent profile for seamless use
        dep = Dependent(
            user_id=user.id,
            name=user.name,
            relationship_type="self",
            notes="Primary profile"
        )
        db.add(dep)
        await db.flush()

    token = create_access_token(user_id=user.id, email=user.email)
    return TokenOut(token=token, user=UserOut.model_validate(user))

@router.get("/profile", response_model=UserOut)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserOut.model_validate(current_user)

@router.put("/profile", response_model=UserOut)
async def update_profile(
    req: ProfileUpdateIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if req.name is not None:
        current_user.name = req.name
    if req.phone is not None:
        current_user.phone = req.phone
    if req.photo_url is not None:
        current_user.photo_url = req.photo_url
    
    await db.flush()
    await db.refresh(current_user)
    return UserOut.model_validate(current_user)
