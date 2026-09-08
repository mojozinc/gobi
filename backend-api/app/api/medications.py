from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.db.session import get_db
from app.db.models import User, Medication, DoseLog
from app.schemas.medication import MedicationCreateIn, MedicationOut, DoseLogOut
from app.api.deps import get_current_user

router = APIRouter(prefix="/medications", tags=["Medications"])

@router.get("", response_model=List[MedicationOut])
async def list_medications(
    dependent_id: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    q = select(Medication).where(Medication.user_id == current_user.id, Medication.is_active == True)
    if dependent_id is not None:
        q = q.where(Medication.dependent_id == dependent_id)
    res = await db.execute(q.order_by(desc(Medication.created_at)))
    return [MedicationOut.model_validate(m) for m in res.scalars().all()]

@router.post("", response_model=MedicationOut, status_code=status.HTTP_201_CREATED)
async def create_medication(
    req: MedicationCreateIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Calculate duration & default inventory
    duration_weeks = req.duration_weeks or 1
    inventory = req.inventory_count if req.inventory_count is not None else (duration_weeks * (7 if req.frequency == "daily" else 1))

    med = Medication(
        user_id=current_user.id,
        dependent_id=req.dependent_id,
        name=req.name,
        dosage=req.dosage or "1 dose",
        frequency=req.frequency,
        times=req.times or "08:00",
        duration_weeks=duration_weeks,
        inventory_count=inventory,
        instructions=req.instructions,
        is_active=True
    )
    db.add(med)
    await db.flush()
    await db.refresh(med)

    # Automatically generate DoseLogs for schedule
    now = datetime.now(timezone.utc)
    doses_to_create: List[DoseLog] = []

    if req.frequency == "weekly":
        for week in range(duration_weeks):
            scheduled = now + timedelta(weeks=week)
            doses_to_create.append(DoseLog(
                user_id=current_user.id,
                dependent_id=req.dependent_id,
                medication_id=med.id,
                scheduled_time=scheduled,
                status="pending",
                dose_number=week + 1,
                notes=f"Week {week + 1} dose"
            ))
    elif req.frequency == "twice_daily":
        total_days = duration_weeks * 7
        for day in range(total_days):
            doses_to_create.append(DoseLog(
                user_id=current_user.id,
                dependent_id=req.dependent_id,
                medication_id=med.id,
                scheduled_time=now.replace(hour=8, minute=0, second=0) + timedelta(days=day),
                status="pending",
                dose_number=day * 2 + 1,
                notes="Morning dose"
            ))
            doses_to_create.append(DoseLog(
                user_id=current_user.id,
                dependent_id=req.dependent_id,
                medication_id=med.id,
                scheduled_time=now.replace(hour=20, minute=0, second=0) + timedelta(days=day),
                status="pending",
                dose_number=day * 2 + 2,
                notes="Evening dose"
            ))
    else: # Daily
        total_days = duration_weeks * 7
        for day in range(total_days):
            scheduled = now + timedelta(days=day)
            doses_to_create.append(DoseLog(
                user_id=current_user.id,
                dependent_id=req.dependent_id,
                medication_id=med.id,
                scheduled_time=scheduled,
                status="pending",
                dose_number=day + 1,
                notes=f"Day {day + 1} dose"
            ))

    for d in doses_to_create:
        db.add(d)

    await db.flush()
    return MedicationOut.model_validate(med)

@router.get("/doses/today", response_model=List[DoseLogOut])
async def list_today_doses(
    dependent_id: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    q = (
        select(DoseLog, Medication.name.label("med_name"), Medication.dosage.label("med_dosage"))
        .join(Medication, DoseLog.medication_id == Medication.id)
        .where(
            DoseLog.user_id == current_user.id,
            DoseLog.scheduled_time >= today_start - timedelta(days=7), # Include overdue/current week doses
            DoseLog.scheduled_time <= today_end
        )
        .order_by(DoseLog.scheduled_time)
    )
    if dependent_id is not None:
        q = q.where(DoseLog.dependent_id == dependent_id)

    res = await db.execute(q)
    results = []
    for log, name, dosage in res.all():
        out = DoseLogOut.model_validate(log)
        out.medication_name = name
        out.dosage = dosage
        results.append(out)
    return results

@router.post("/doses/{id}/take", response_model=DoseLogOut)
async def take_dose(
    id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(
        select(DoseLog).where(DoseLog.id == id, DoseLog.user_id == current_user.id)
    )
    dose = res.scalar_one_or_none()
    if not dose:
        raise HTTPException(status_code=404, detail="Dose log not found")

    dose.status = "taken"
    dose.actual_time = datetime.now(timezone.utc)

    # Decrement medication inventory
    med_res = await db.execute(select(Medication).where(Medication.id == dose.medication_id))
    med = med_res.scalar_one_or_none()
    if med and med.inventory_count > 0:
        med.inventory_count -= 1

    await db.flush()
    await db.refresh(dose)
    
    out = DoseLogOut.model_validate(dose)
    if med:
        out.medication_name = med.name
        out.dosage = med.dosage
    return out

@router.post("/doses/{id}/undo", response_model=DoseLogOut)
async def undo_dose(
    id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    res = await db.execute(
        select(DoseLog).where(DoseLog.id == id, DoseLog.user_id == current_user.id)
    )
    dose = res.scalar_one_or_none()
    if not dose:
        raise HTTPException(status_code=404, detail="Dose log not found")

    if dose.status == "taken":
        dose.status = "pending"
        dose.actual_time = None

        # Restore inventory
        med_res = await db.execute(select(Medication).where(Medication.id == dose.medication_id))
        med = med_res.scalar_one_or_none()
        if med:
            med.inventory_count += 1

    await db.flush()
    await db.refresh(dose)
    
    out = DoseLogOut.model_validate(dose)
    if med:
        out.medication_name = med.name
        out.dosage = med.dosage
    return out
