import uuid

from src.models import PayRequest, PayResponse


def pay(request: PayRequest) -> PayResponse:
    return PayResponse(
        status="paid", order_id=request.order_id, transaction_id=str(uuid.uuid4())
    )
