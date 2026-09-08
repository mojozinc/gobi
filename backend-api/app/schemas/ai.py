from typing import Optional, List, Any, Dict
from pydantic import BaseModel

class VoiceIntentRequest(BaseModel):
    text: str
    dependent_id: Optional[int] = None

class SetScheduleArgs(BaseModel):
    name: str
    dosage: Optional[str] = "1 dose"
    frequency: str = "daily"
    duration_weeks: Optional[int] = 1
    times: Optional[str] = "08:00"
    instructions: Optional[str] = None

class RecordDoseArgs(BaseModel):
    name: str
    status: str = "taken" # taken, skipped
    time_taken: Optional[str] = None

class GetScheduleArgs(BaseModel):
    name: Optional[str] = None
    timeframe: Optional[str] = "today"

class VoiceIntentResponse(BaseModel):
    action: str # SET_SCHEDULE, RECORD_DOSE, GET_SCHEDULE, UNKNOWN
    message: str
    raw_query: str
    set_schedule_data: Optional[SetScheduleArgs] = None
    record_dose_data: Optional[RecordDoseArgs] = None
    get_schedule_data: Optional[GetScheduleArgs] = None
    requires_confirmation: bool = True

class PrescriptionMedicationItem(BaseModel):
    name: str
    dosage: Optional[str] = "1 tablet"
    frequency: str = "daily" # daily, twice_daily, weekly, as_needed
    duration_weeks: Optional[int] = 1
    instructions: Optional[str] = None

class ScanPrescriptionResponse(BaseModel):
    doctor_name: Optional[str] = None
    date: Optional[str] = None
    diagnosis: Optional[str] = None
    notes: Optional[str] = None
    medications: List[PrescriptionMedicationItem] = []

class ChatMessage(BaseModel):
    role: str # user, assistant, system
    content: str

class ChatRequest(BaseModel):
    query: str
    dependent_id: Optional[int] = None
    conversation_history: Optional[List[ChatMessage]] = []

class ChatResponse(BaseModel):
    response: str
    referenced_medications: List[str] = []
    referenced_documents: List[str] = []
