from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict

class MedicationCreateIn(BaseModel):
    dependent_id: Optional[int] = None
    name: str
    dosage: Optional[str] = "1 dose"
    frequency: str = "daily" # daily, weekly, as_needed
    times: Optional[str] = "08:00"
    duration_weeks: Optional[int] = 1
    inventory_count: Optional[int] = None
    instructions: Optional[str] = None

class MedicationOut(BaseModel):
    id: int
    user_id: int
    dependent_id: Optional[int] = None
    name: str
    dosage: Optional[str] = None
    frequency: str
    times: Optional[str] = None
    duration_weeks: int
    inventory_count: int
    instructions: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class DoseLogOut(BaseModel):
    id: int
    user_id: int
    dependent_id: Optional[int] = None
    medication_id: int
    medication_name: Optional[str] = None
    dosage: Optional[str] = None
    scheduled_time: datetime
    actual_time: Optional[datetime] = None
    status: str # pending, taken, skipped
    dose_number: int
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
