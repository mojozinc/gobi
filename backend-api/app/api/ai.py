import base64
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import get_db
from app.db.models import User, Document, Medication, DoseLog
from app.schemas.ai import (
    VoiceIntentRequest, VoiceIntentResponse,
    ScanPrescriptionResponse, ChatRequest, ChatResponse
)
from app.services.openrouter import openrouter_service
from app.services.rag import build_user_health_context
from app.api.deps import get_current_user

router = APIRouter(prefix="/ai", tags=["AI"])

@router.post("/parse-intent", response_model=VoiceIntentResponse)
async def parse_voice_intent(
    req: VoiceIntentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Retrieve light context (e.g. list of user's active medication names for fuzzy matching)
    res = await db.execute(
        select(Medication.name).where(Medication.user_id == current_user.id, Medication.is_active == True)
    )
    active_med_names = [row[0] for row in res.all()]
    context = f"User's Active Medications: {', '.join(active_med_names) if active_med_names else 'None'}"

    intent = await openrouter_service.parse_voice_intent(user_text=req.text, context=context)
    return intent

@router.post("/scan-prescription", response_model=ScanPrescriptionResponse)
async def scan_prescription(
    file: UploadFile = File(...),
    dependent_id: Optional[int] = Form(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Read image contents
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty image file uploaded")

    mime_type = file.content_type or "image/jpeg"
    image_b64 = base64.b64encode(file_bytes).decode("utf-8")

    # Call OpenRouter Multimodal Vision
    ocr_result = await openrouter_service.scan_prescription(image_base64=image_b64, mime_type=mime_type)

    # Save document record to database
    doc_text_summary = f"Doctor: {ocr_result.doctor_name or 'N/A'}\nDate: {ocr_result.date or 'N/A'}\nMedications:\n"
    for m in ocr_result.medications:
        doc_text_summary += f"- {m.name} ({m.dosage}, {m.frequency}, {m.duration_weeks} wks): {m.instructions or ''}\n"

    doc = Document(
        user_id=current_user.id,
        dependent_id=dependent_id,
        title=f"Prescription - {ocr_result.doctor_name or file.filename}",
        doc_type="prescription",
        raw_text=doc_text_summary,
        parsed_json=ocr_result.model_dump()
    )
    db.add(doc)
    await db.flush()

    return ocr_result

@router.post("/chat", response_model=ChatResponse)
async def health_chat(
    req: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Build RAG health context from SQLite/Postgres DB
    context = await build_user_health_context(
        db=db,
        user_id=current_user.id,
        dependent_id=req.dependent_id
    )

    # 2. Format conversation history
    history = [{"role": msg.role, "content": msg.content} for msg in req.conversation_history or []]

    # 3. Call OpenRouter with RAG grounding
    ai_reply = await openrouter_service.chat_rag(
        query=req.query,
        context=context,
        history=history
    )

    return ChatResponse(
        response=ai_reply,
        referenced_medications=[],
        referenced_documents=[]
    )
