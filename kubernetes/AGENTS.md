## Kubernetes Layer Brief

- 현재 `kubernetes/`는 구현 전 단계다.
- 이 디렉토리는 Terraform 이후 단계의 **클러스터 내 배포/라우팅 수명주기**를 담당한다.

## Expected Ownership

- Cilium 설치 및 값 관리
- AWS Gateway API Controller 설치 + IRSA 연계
- Gateway/HTTPRoute/ServiceExport/ServiceImport 매니페스트
- 데모 앱 배포 매니페스트

## Design Intention

- Terraform과 책임 분리: 인프라 생성과 K8s 리소스 변경 속도를 분리한다.
- sidecarless 메시지 유지: 워크로드 per-pod sidecar 없이 경계 서비스 네트워킹을 검증한다.

## Critical Constraints

- Lattice service network 이름과 Kubernetes Gateway 이름의 정합성을 반드시 유지한다.
- IAMAuthPolicy는 Gateway/Route 경유 트래픽에만 기대할 수 있으므로 우회 경로 방지 전략을 함께 설계한다.
- 멀티 리전은 현재 데모 범위 밖이다.

## First Priority Work

1. 컨트롤러(Cilium + AWS Gateway API Controller) 설치 기반 추가
2. checkout/inventory 간 cross-VPC 경로를 검증할 최소 Gateway/Route 예시 추가
3. 운영/검증 순서(runbook) 문서화
