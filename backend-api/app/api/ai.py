import base64
import logging
import time
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.session import get_db
from app.db.models import User, Document, Medication, DoseLog, Dependent
from app.schemas.ai import (
    VoiceIntentRequest, VoiceIntentResponse,
    ScanPrescriptionResponse, ChatRequest, ChatResponse
)
from app.services.openrouter import openrouter_service
from app.services.rag import build_user_health_context
from app.api.deps import get_current_user

logger = logging.getLogger("gobi.ai")

router = APIRouter(prefix="/ai", tags=["AI"])

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

async def _verify_dependent(db: AsyncSession, dependent_id: Optional[int], user_id: int):
    if dependent_id is not None:
        dep_res = await db.execute(
            select(Dependent).where(Dependent.id == dependent_id, Dependent.user_id == user_id)
        )
        if not dep_res.scalar_one_or_none():
            logger.warning(f"Access denied for dependent_id={dependent_id} and user_id={user_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Dependent not found or access denied"
            )

@router.post("/parse-intent", response_model=VoiceIntentResponse)
async def parse_voice_intent(
    req: VoiceIntentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    logger.info(f"[PARSE INTENT] User: {current_user.name} (ID={current_user.id}) | Text: '{req.text}'")
    if req.dependent_id is not None:
        await _verify_dependent(db, req.dependent_id, current_user.id)

    # Retrieve light context (e.g. list of user's active medication names for fuzzy matching)
    res = await db.execute(
        select(Medication.name).where(Medication.user_id == current_user.id, Medication.is_active == True)
    )
    active_med_names = [row[0] for row in res.all()]
    context = f"User's Active Medications: {', '.join(active_med_names) if active_med_names else 'None'}"
    logger.debug(f"[PARSE INTENT CONTEXT] {context}")

    intent = await openrouter_service.parse_voice_intent(user_text=req.text, context=context)
    logger.info(f"[PARSE INTENT RESULT] Action: {intent.action} | Message: '{intent.message}'")
    return intent

@router.post("/scan-prescription", response_model=ScanPrescriptionResponse)
async def scan_prescription(
    file: UploadFile = File(...),
    dependent_id: Optional[int] = Form(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    logger.info(f"[SCAN PRESCRIPTION] User: {current_user.name} (ID={current_user.id}) | File: {file.filename}")
    if dependent_id is not None:
        await _verify_dependent(db, dependent_id, current_user.id)

    # Read image contents with size constraint
    file_bytes = await file.read()
    if not file_bytes:
        logger.warning("[SCAN PRESCRIPTION] Empty image file uploaded")
        raise HTTPException(status_code=400, detail="Empty image file uploaded")
    if len(file_bytes) > MAX_IMAGE_SIZE_BYTES:
        logger.warning(f"[SCAN PRESCRIPTION] File size exceeds 10MB ({len(file_bytes)} bytes)")
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File size exceeds maximum limit of 10MB"
        )

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
    logger.info(f"[SCAN PRESCRIPTION SAVED] Doc ID: {doc.id} | Doctor: {ocr_result.doctor_name} | Meds: {len(ocr_result.medications)}")

    return ocr_result

@router.post("/chat", response_model=ChatResponse)
async def health_chat(
    req: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    start_time = time.time()
    logger.info(
        f"[CHAT START] User: {current_user.name} (ID={current_user.id}, email={current_user.email}) | "
        f"Query: '{req.query}' | Dependent ID: {req.dependent_id} | "
        f"History turns: {len(req.conversation_history or [])}"
    )

    if req.dependent_id is not None:
        await _verify_dependent(db, req.dependent_id, current_user.id)
        logger.debug(f"[CHAT] Verified access to dependent_id={req.dependent_id}")

    # 1. Build RAG health context from SQLite/Postgres DB
    context = await build_user_health_context(
        db=db,
        user_id=current_user.id,
        dependent_id=req.dependent_id
    )
    logger.debug(f"[CHAT RAG CONTEXT] Length: {len(context)} chars\n--- CONTEXT PREVIEW ---\n{context}\n----------------------")

    # 2. Format conversation history
    history = [{"role": msg.role, "content": msg.content} for msg in req.conversation_history or []]
    logger.debug(f"[CHAT HISTORY] Turns: {len(history)} | Messages: {history}")

    # 3. Call OpenRouter with RAG grounding
    logger.info(f"[CHAT LLM] Dispatching to OpenRouter model: {openrouter_service.text_model}...")
    ai_reply = await openrouter_service.chat_rag(
        query=req.query,
        context=context,
        history=history
    )
    duration_ms = (time.time() - start_time) * 1000
    logger.info(
        f"[CHAT COMPLETE] Finished in {duration_ms:.1f}ms | "
        f"Response Preview ({len(ai_reply)} chars): '{ai_reply[:120]}...'"
    )

    return ChatResponse(
        response=ai_reply,
        referenced_medications=[],
        referenced_documents=[]
    )
