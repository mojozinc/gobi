from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict

class DependentCreateIn(BaseModel):
    name: str
    relationship_type: str # self, parent, child, spouse
    age: Optional[int] = None
    gender: Optional[str] = None
    notes: Optional[str] = None

class DependentOut(BaseModel):
    id: int
    user_id: int
    name: str
    relationship_type: str
    age: Optional[int] = None
    gender: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
