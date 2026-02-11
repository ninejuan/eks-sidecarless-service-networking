from pydantic import BaseModel, Field


class PayRequest(BaseModel):
    order_id: str = Field(..., alias="orderId", min_length=1)
    amount: int = Field(..., ge=1)
    currency: str = Field(default="KRW", min_length=3, max_length=3)


class PayResponse(BaseModel):
    status: str
    order_id: str = Field(serialization_alias="orderId")
    transaction_id: str = Field(serialization_alias="transactionId")


class HealthResponse(BaseModel):
    service: str
    status: str
    version: str
