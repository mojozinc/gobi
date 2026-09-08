from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import get_db
from app.db.models import User, Dependent
from app.schemas.dependent import DependentCreateIn, DependentOut
from app.api.deps import get_current_user

router = APIRouter(prefix="/dependents", tags=["Dependents"])

@router.get("", response_model=List[DependentOut])
async def list_dependents(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(
        select(Dependent).where(Dependent.user_id == current_user.id).order_by(Dependent.id)
    )
    return [DependentOut.model_validate(d) for d in res.scalars().all()]

@router.post("", response_model=DependentOut, status_code=status.HTTP_201_CREATED)
async def create_dependent(
    req: DependentCreateIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    dep = Dependent(
        user_id=current_user.id,
        name=req.name,
        relationship_type=req.relationship_type,
        age=req.age,
        gender=req.gender,
        notes=req.notes
    )
    db.add(dep)
    await db.flush()
    await db.refresh(dep)
    return DependentOut.model_validate(dep)

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_dependent(
    id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(
        select(Dependent).where(Dependent.id == id, Dependent.user_id == current_user.id)
    )
    dep = res.scalar_one_or_none()
    if not dep:
        raise HTTPException(status_code=404, detail="Dependent not found")
    
    await db.delete(dep)
