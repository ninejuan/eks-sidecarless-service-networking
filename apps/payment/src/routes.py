from fastapi import APIRouter

from src.models import PayRequest, PayResponse
from src.service import pay

router = APIRouter(prefix="/v1/payment", tags=["payment-v1"])


@router.post("/pay", response_model=PayResponse)
async def pay_endpoint(payload: PayRequest) -> PayResponse:
    return pay(payload)
