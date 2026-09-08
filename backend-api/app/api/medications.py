from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.db.session import get_db
from app.db.models import User, Medication, DoseLog, Dependent
from app.schemas.medication import MedicationCreateIn, MedicationOut, DoseLogOut
from app.api.deps import get_current_user

router = APIRouter(prefix="/medications", tags=["Medications"])

async def _verify_dependent(db: AsyncSession, dependent_id: Optional[int], user_id: int):
    if dependent_id is not None:
        dep_res = await db.execute(
            select(Dependent).where(Dependent.id == dependent_id, Dependent.user_id == user_id)
        )
        if not dep_res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Dependent not found or access denied"
            )

def _parse_time_slots(times_str: Optional[str]) -> List[tuple[int, int]]:
    slots: List[tuple[int, int]] = []
    if times_str:
        for t in times_str.split(","):
            t = t.strip()
            if not t:
                continue
            parts = t.split(":")
            if len(parts) >= 2:
                try:
                    h = int(parts[0])
                    m = int(parts[1][:2])
                    if 0 <= h <= 23 and 0 <= m <= 59:
                        slots.append((h, m))
                except ValueError:
                    pass
    if not slots:
        slots = [(8, 0)]
    return slots

@router.get("", response_model=List[MedicationOut])
async def list_medications(
    dependent_id: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if dependent_id is not None:
        await _verify_dependent(db, dependent_id, current_user.id)
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
    if req.dependent_id is not None:
        await _verify_dependent(db, req.dependent_id, current_user.id)

    duration_weeks = req.duration_weeks or 1
    times_str = req.times or "08:00"
    time_slots = _parse_time_slots(times_str)

    # Calculate default inventory based on frequency and slots
    freq = req.frequency.lower()
    if freq == "weekly":
        total_doses = duration_weeks * len(time_slots)
    elif freq == "twice_daily":
        if len(time_slots) < 2:
            time_slots = [(8, 0), (20, 0)]
            times_str = "08:00, 20:00"
        total_doses = duration_weeks * 7 * len(time_slots)
    elif freq == "as_needed":
        total_doses = req.inventory_count if req.inventory_count is not None else 10
    else:  # daily or other
        total_doses = duration_weeks * 7 * len(time_slots)

    inventory = req.inventory_count if req.inventory_count is not None else total_doses

    med = Medication(
        user_id=current_user.id,
        dependent_id=req.dependent_id,
        name=req.name,
        dosage=req.dosage or "1 dose",
        frequency=req.frequency,
        times=times_str,
        duration_weeks=duration_weeks,
        inventory_count=inventory,
        instructions=req.instructions,
        is_active=True
    )
    db.add(med)
    await db.flush()
    await db.refresh(med)

    # Automatically generate DoseLogs for schedule starting from today's midnight UTC
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    doses_to_create: List[DoseLog] = []

    if freq == "weekly":
        dose_num = 1
        for week in range(duration_weeks):
            for h, m in time_slots:
                scheduled = today_start.replace(hour=h, minute=m) + timedelta(weeks=week)
                doses_to_create.append(DoseLog(
                    user_id=current_user.id,
                    dependent_id=req.dependent_id,
                    medication_id=med.id,
                    scheduled_time=scheduled,
                    status="pending",
                    dose_number=dose_num,
                    notes=f"Week {week + 1} dose"
                ))
                dose_num += 1
    elif freq != "as_needed":
        total_days = duration_weeks * 7
        dose_num = 1
        for day in range(total_days):
            for h, m in time_slots:
                scheduled = today_start.replace(hour=h, minute=m) + timedelta(days=day)
                doses_to_create.append(DoseLog(
                    user_id=current_user.id,
                    dependent_id=req.dependent_id,
                    medication_id=med.id,
                    scheduled_time=scheduled,
                    status="pending",
                    dose_number=dose_num,
                    notes=f"Day {day + 1} dose ({h:02d}:{m:02d})"
                ))
                dose_num += 1

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
    if dependent_id is not None:
        await _verify_dependent(db, dependent_id, current_user.id)

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
