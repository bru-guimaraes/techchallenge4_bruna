from pydantic import BaseModel
from typing import List

class PrevisaoRequest(BaseModel):
    historico: List[float]
