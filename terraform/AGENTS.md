## Terraform Layer Brief

- 이 디렉토리는 EKS sidecarless 데모의 **기반 인프라 수명주기**를 담당한다.
- 현재 기준 운영 환경은 `envs/demo` 단일 환경이다.
- 핵심 전제는 **single account + multiple VPC** 이다.

## Directory Role

- `envs/demo/`: 실제 조합 루트.
- `modules/networking/`: VPC, subnet, route, NAT 등 네트워크 기반.
- `modules/eks/`: EKS 클러스터/노드/IRSA/Gateway API Controller IAM 기반.
- `modules/lattice_service_network/`: VPC Lattice service network.
- `modules/lattice_vpc_association/`: VPC-Lattice association.
- `modules/ecr/`: 서비스 이미지 저장소.
- `modules/dynamodb/`: inventory 데이터 저장소.

## Non-Negotiable Boundaries

- Terraform은 **기반 인프라**만 관리한다.
- EKS 클러스터는 기본 addon(VPC CNI, CoreDNS, kube-proxy) 포함 상태로 생성한다.
- `kubernetes/` 계층(Kustomize)에서 VPC CNI/kube-proxy를 삭제하고 Cilium으로 교체한다.
- Gateway API Controller IAM(role, policy)은 Terraform에서 프로비저닝하되, 컨트롤러 배포와 Pod Identity Association은 `kubernetes/` 계층에서 관리한다.
- Gateway/Route 등 라우팅 리소스는 Terraform에서 직접 배포하지 않는다.
- K8s 라우팅 리소스는 `kubernetes/` 계층(Kustomize)에서 관리한다.

## Demo Topology (Current)

- `vpc_foo` + `eks_foo`
- `vpc_bar` + `eks_bar`
- 단일 Lattice service network에 foo/bar VPC를 association.
- shared resources: ECR(checkout, inventory, payment, delivery), DynamoDB(inventory).

## Update Rules

- 새 모듈 추가 시 `envs/demo/main.tf` 호출부 + `outputs.tf` 노출값을 함께 갱신한다.
- 변수 추가 시 `variables.tf`에 description/기본값/타입을 명시한다.
- 아키텍처 의미가 바뀌면 `.sisyphus/PROJECT_BRIEF_FOR_AGENTS.md`도 동기화한다.
