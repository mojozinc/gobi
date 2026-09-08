from datetime import datetime, timezone, timedelta
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.db.models import User, Dependent, Medication, DoseLog, Document

async def build_user_health_context(
    db: AsyncSession,
    user_id: int,
    dependent_id: Optional[int] = None
) -> str:
    """Builds a formatted summary of user's active medications, adherence logs, and prescriptions for RAG."""
    sections: List[str] = []

    # 1. User & Dependent Profile
    user_res = await db.execute(select(User).where(User.id == user_id))
    user = user_res.scalar_one_or_none()
    user_name = user.name if user else "User"
    
    profile_info = f"Current User: {user_name} (ID: {user_id})"
    if dependent_id:
        dep_res = await db.execute(select(Dependent).where(Dependent.id == dependent_id, Dependent.user_id == user_id))
        dep = dep_res.scalar_one_or_none()
        if dep:
            profile_info += f" | Viewing Dependent: {dep.name} (Relationship: {dep.relationship_type})"
    sections.append(f"### Profile:\n{profile_info}")

    # 2. Active Medications
    med_query = select(Medication).where(Medication.user_id == user_id, Medication.is_active == True)
    if dependent_id:
        med_query = med_query.where(Medication.dependent_id == dependent_id)
    med_res = await db.execute(med_query)
    meds = med_res.scalars().all()

    if meds:
        med_lines = []
        for m in meds:
            med_lines.append(
                f"- **{m.name}** | Dosage: {m.dosage or 'N/A'} | Frequency: {m.frequency} | "
                f"Schedule Times: {m.times or '08:00'} | Inventory Left: {m.inventory_count} doses | Notes: {m.instructions or 'None'}"
            )
        sections.append("### Active Medications:\n" + "\n".join(med_lines))
    else:
        sections.append("### Active Medications:\nNo active medications recorded.")

    # 3. Recent Dose Logs (Past 7 Days & Upcoming Today)
    since_date = datetime.now(timezone.utc) - timedelta(days=7)
    dose_query = (
        select(DoseLog, Medication.name.label("med_name"))
        .join(Medication, DoseLog.medication_id == Medication.id)
        .where(DoseLog.user_id == user_id, DoseLog.scheduled_time >= since_date)
        .order_by(desc(DoseLog.scheduled_time))
        .limit(20)
    )
    if dependent_id:
        dose_query = dose_query.where(DoseLog.dependent_id == dependent_id)
    dose_res = await db.execute(dose_query)
    dose_rows = dose_res.all()

    if dose_rows:
        dose_lines = []
        for log, med_name in dose_rows:
            sched_str = log.scheduled_time.strftime("%Y-%m-%d %H:%M")
            actual_str = log.actual_time.strftime("%Y-%m-%d %H:%M") if log.actual_time else "Not Taken"
            dose_lines.append(
                f"- {med_name} (Dose #{log.dose_number}): Scheduled {sched_str} -> Status: **{log.status.upper()}** (Actual: {actual_str})"
            )
        sections.append("### Recent Adherence & Dose Logs:\n" + "\n".join(dose_lines))
    else:
        sections.append("### Recent Adherence & Dose Logs:\nNo recent dose records.")

    # 4. Scanned Prescriptions & Documents
    doc_query = (
        select(Document)
        .where(Document.user_id == user_id)
        .order_by(desc(Document.created_at))
        .limit(5)
    )
    if dependent_id:
        doc_query = doc_query.where(Document.dependent_id == dependent_id)
    doc_res = await db.execute(doc_query)
    docs = doc_res.scalars().all()

    if docs:
        doc_lines = []
        for d in docs:
            doc_lines.append(f"- **{d.title}** ({d.doc_type}) - Created: {d.created_at.strftime('%Y-%m-%d')}\n  Details: {d.raw_text or 'Scanned prescription'}")
        sections.append("### Scanned Documents & Prescriptions:\n" + "\n".join(doc_lines))

    return "\n\n".join(sections)
