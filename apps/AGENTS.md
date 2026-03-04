## Application Layer Brief

- 이 디렉토리는 데모용 마이크로서비스 4종을 포함한다.
  - `checkout`: 오케스트레이션 엔트리 서비스
  - `inventory`: 재고 서비스 (DynamoDB)
  - `payment`: 결제 서비스
  - `delivery`: 배송 서비스

## Contract Baseline

- 모든 서비스는 최소 아래 헬스 엔드포인트를 제공해야 한다.
  - `/health`
  - `/health/liveness`
  - `/health/readiness`
- 설정은 `.env` 기반으로 주입하고 하드코딩을 피한다.
- 로그는 stdout으로 출력하고, 공통 필드(timestamp, level, msg, service, env 등)를 유지한다.

## Current Call Flow

- 기본 시나리오는 `checkout -> inventory/payment/delivery` 순차 호출이다.
- 로컬 기본값은 localhost URL이며, Lattice 데모에서는 경계 트래픽 주소로 치환해야 한다.

## Implementation Notes

- checkout/inventory는 Go(chi) 기반.
- payment는 FastAPI(Python) 기반.
- delivery는 Fastify(Node.js) 기반.
- 언어별 패키지/실행 규칙은 루트 `AGENTS.md`를 우선 적용한다.

## Change Rules

- 서비스 계약(API/헬스/의존성)이 바뀌면 `.sisyphus/PROJECT_BRIEF_FOR_AGENTS.md`를 같이 갱신한다.
- cross-service 호출 경로를 수정할 때는 정책 우회 가능성(직접 service DNS 호출)을 문서에 명시한다.
