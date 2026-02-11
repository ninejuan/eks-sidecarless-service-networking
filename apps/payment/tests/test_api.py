import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))

from main import app

client = TestClient(app)


def test_health_endpoints() -> None:
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["service"] == "payment"

    liveness = client.get("/health/liveness")
    assert liveness.status_code == 200
    assert liveness.json()["status"] == "alive"

    readiness = client.get("/health/readiness")
    assert readiness.status_code == 200
    assert readiness.json()["status"] == "ready"


def test_pay_endpoint() -> None:
    response = client.post(
        "/v1/payment/pay",
        json={"orderId": "order-1", "amount": 10000, "currency": "KRW"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "paid"
    assert body["orderId"] == "order-1"
    assert "transactionId" in body
