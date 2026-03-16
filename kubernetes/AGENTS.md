## Kubernetes Layer Brief

- 이 디렉토리는 Terraform 이후 단계의 **클러스터 내 배포/라우팅 수명주기**를 담당한다.
- Kustomize + helmCharts 기반으로 구성되며, `kustomize build --enable-helm`이 필요하다.

## Ownership

- cert-manager 설치 (helmCharts via overlay, foo 클러스터 전용)
- Cilium ENI 모드 설치 (helmCharts via overlay)
- AWS Load Balancer Controller 설치 (helmCharts via overlay, foo 클러스터 전용, cert-manager로 webhook TLS 관리)
- AWS Gateway API Controller 설치 (OCI chart: `oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart`)
- Gateway/HTTPRoute 매니페스트 (VPC Lattice service network 매핑)
- Ingress 매니페스트 (ALB Ingress, foo 클러스터 전용)
- 데모 앱 4종 배포 매니페스트 (Deployment + Service + Namespace + ServiceAccount)

## Directory Structure

```
kubernetes/
├── base/
│   ├── cert-manager/                  # cert-manager 공통 values.yaml (foo 클러스터 전용)
│   ├── cilium/                        # Cilium 공통 values.yaml (helmCharts는 overlay에서 inflate)
│   ├── aws-lb-controller/             # AWS LB Controller 공통 values.yaml (enableCertManager: true)
│   ├── gateway-api-controller/        # Gateway API Controller 공통 values.yaml
│   └── apps/                          # 앱별 Deployment/Service/Namespace/ServiceAccount
│       ├── checkout/                  # Go/chi, port 8080
│       ├── inventory/                 # Go/chi, port 8081, DynamoDB 의존
│       ├── payment/                   # Python/FastAPI, port 8082
│       └── delivery/                  # Node.js/Fastify, port 8083
├── overlays/
│   ├── foo/                           # foo 클러스터: checkout만 배포
│   │   ├── kustomization.yaml         # helmCharts(cert-manager, cilium, lbc, gateway-api) + apps + patches
│   │   ├── values-cert-manager.yaml   # cert-manager overlay values
│   │   ├── values-cilium.yaml         # foo VPC CIDR: 10.0.0.0/16
│   │   ├── values-lb-controller.yaml  # LBC overlay values (enableCertManager: true)
│   │   ├── values-gateway-api.yaml    # foo IAM role ARN
│   │   ├── gateway.yaml               # Gateway → Lattice service network
│   │   ├── httproutes.yaml            # checkout HTTPRoute
│   │   └── ingress.yaml               # ALB Ingress for checkout
│   └── bar/                           # bar 클러스터: inventory + payment + delivery 배포
│       ├── kustomization.yaml
│       ├── values-cilium.yaml         # bar VPC CIDR: 192.168.0.0/16
│       ├── values-gateway-api.yaml    # bar IAM role ARN
│       ├── gateway.yaml
│       └── httproutes.yaml            # inventory/payment/delivery HTTPRoute
└── Makefile                           # (루트 Makefile에서 관리)
```

## App Placement

- **foo 클러스터**: checkout (오케스트레이터, 단독)
- **bar 클러스터**: inventory + payment + delivery
- checkout의 모든 downstream 호출이 VPC Lattice를 통과하여 cross-VPC networking을 데모한다.

## Namespace Strategy

- 앱별 namespace: `checkout`, `inventory`, `payment`, `delivery`
- cert-manager: `cert-manager` (foo 클러스터 전용)
- Cilium: `kube-system`
- AWS Load Balancer Controller: `kube-system` (foo 클러스터 전용)
- Gateway API Controller: `aws-application-networking-system`

## Design Intention

- Terraform과 책임 분리: 인프라 생성과 K8s 리소스 변경 속도를 분리한다.
- sidecarless 유지: 워크로드 per-pod sidecar 없이 경계 서비스 네트워킹을 검증한다.
- helmCharts는 overlay에서만 inflate: 클러스터별 VPC CIDR, IAM role 등 차이를 overlay values로 관리한다.
- cert-manager로 webhook TLS 관리: AWS LB Controller의 webhook 인증서를 cert-manager가 자동 발급/갱신한다. kustomize 재빌드 시 CA 불일치(x509 에러)를 방지한다.

## 3-Phase Apply Strategy (foo 클러스터)

Makefile의 AWK splitter가 `kustomize build` 출력을 3개 파일로 분류한다:

1. **Phase 0 (certmanager.yaml)**: `cert-manager` namespace 또는 이름에 `cert-manager`를 포함하는 리소스. cert-manager CRD, controller, webhook, cainjector 등.
2. **Phase 1 (base.yaml)**: Cilium, AWS LB Controller (+ Certificate/Issuer), Gateway API Controller, 앱 리소스. cert-manager가 ready 상태여야 LBC webhook 인증서가 발급된다.
3. **Phase 2 (deferred.yaml)**: `Gateway`, `HTTPRoute`, `Ingress`, `TargetGroupPolicy`. 컨트롤러가 CRD를 등록한 후에만 apply 가능.

bar 클러스터는 cert-manager/LBC가 없으므로 2-phase (base + deferred)로 동작한다.

### AWK 분류 기준

```
DEFERRED_KINDS: TargetGroupPolicy|Gateway|HTTPRoute|Ingress

우선순위:
1. ns == "cert-manager" || name ~ /cert-manager/ → certmanager 파일
2. kind가 DEFERRED_KINDS에 해당 → deferred 파일
3. 나머지 → base 파일
```

## Critical Constraints

- Lattice service network 이름(`summit-demo-service-network`)과 Kubernetes Gateway 이름의 정합성을 반드시 유지한다.
- Gateway는 `aws-application-networking-system` namespace에 배치하고 `allowedRoutes.namespaces.from: All`로 cross-namespace HTTPRoute를 허용한다.
- IAMAuthPolicy는 Gateway/Route 경유 트래픽에만 기대할 수 있으므로 우회 경로 방지 전략을 함께 설계한다.
- cert-manager는 반드시 AWS LB Controller보다 먼저 배포되어야 한다. LBC의 `enableCertManager: true` 설정은 cert-manager의 Certificate/Issuer CRD에 의존한다.
- cert-manager의 SelfSigned Issuer → Root CA → CA Issuer 체인이 LBC webhook serving cert를 발급한다. 이 체인을 수동으로 변경하지 않는다.
- 멀티 리전은 현재 데모 범위 밖이다.

## Required Environment Variables (Makefile)

- `FOO_CONTEXT` / `BAR_CONTEXT`: kubectl context
- `AWS_ACCOUNT_ID`: ECR 이미지 참조용
- `FOO_GATEWAY_API_CONTROLLER_ROLE_ARN` / `BAR_GATEWAY_API_CONTROLLER_ROLE_ARN`: IAM role ARN
- `FOO_LB_CONTROLLER_ROLE_ARN`: AWS LB Controller IAM role ARN (foo 클러스터 전용)
- `INVENTORY_LATTICE_DNS` / `PAYMENT_LATTICE_DNS` / `DELIVERY_LATTICE_DNS`: Lattice 생성 DNS (런타임 결정)
