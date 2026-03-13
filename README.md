# EKS Sidecarless Service Networking

Reference architectures and demos for building sidecarless service networking on Amazon EKS using Amazon VPC Lattice, Cilium, and Kubernetes Gateway API. This repository focuses on multi-VPC and multi-cluster service connectivity, security boundaries, and real-world operational trade-offs. Rather than relying on per-pod sidecar proxies, it delegates boundary networking to VPC Lattice and uses Cilium in ENI mode as the CNI, keeping the data plane lean and the operational surface small.

---

> **Warning:** This repository is intended for architectural exploration and PoC purposes. It highlights design decisions, limitations, and trade-offs rather than providing a one-size-fits-all solution. Do not use this in production.

---

## Architecture Overview

Two VPCs are provisioned in the same AWS region and connected through a VPC Lattice service network. There are no VPC peering connections or Transit Gateway attachments between them. All cross-VPC service traffic flows through VPC Lattice, which handles routing, authentication (SigV4), and observability at the network boundary.

- `foo` VPC (`10.0.0.0/16`): hosts the `foo` EKS cluster. This is the entry point. An ALB Ingress exposes the `checkout` service externally.
- `bar` VPC (`192.168.0.0/16`): hosts the `bar` EKS cluster. This is the backend. `inventory`, `payment`, and `delivery` services run here and are reachable only through VPC Lattice.

Both clusters use Cilium in ENI mode as the CNI, with `kubeProxyReplacement` enabled. There are no sidecar proxies injected into pods. Service-to-service authentication at the VPC Lattice boundary uses SigV4 with `UNSIGNED-PAYLOAD`. Kubernetes Gateway API (with the AWS Gateway API Controller) manages `Gateway`, `HTTPRoute`, and `TargetGroupPolicy` resources that wire up VPC Lattice service associations.

```
                        ┌─────────────────────────────────────────────────────┐
                        │              VPC Lattice Service Network             │
                        └──────────────────────┬──────────────────────────────┘
                                               │
              ┌────────────────────────────────┼────────────────────────────────┐
              │                                │                                │
   ┌──────────▼──────────┐                     │                   ┌────────────▼───────────┐
   │     foo VPC          │                     │                   │      bar VPC            │
   │   10.0.0.0/16        │                     │                   │   192.168.0.0/16        │
   │                      │                     │                   │                         │
   │  ┌────────────────┐  │                     │                   │  ┌───────────────────┐  │
   │  │   ALB Ingress  │  │                     │                   │  │    inventory      │  │
   │  └───────┬────────┘  │                     │                   │  │  (Go/chi :8081)   │  │
   │          │           │                     │                   │  └───────────────────┘  │
   │  ┌───────▼────────┐  │  VPC Lattice calls  │                   │  ┌───────────────────┐  │
   │  │   checkout     ├──┼─────────────────────┘                   │  │    payment        │  │
   │  │ (Go/chi :8080) │  │                                         │  │ (Python/FastAPI   │  │
   │  └────────────────┘  │                                         │  │       :8082)      │  │
   │                      │                                         │  └───────────────────┘  │
   │   foo EKS cluster    │                                         │  ┌───────────────────┐  │
   │   Cilium ENI mode    │                                         │  │    delivery       │  │
   └──────────────────────┘                                         │  │ (Node.js/Fastify  │  │
                                                                    │  │       :8083)      │  │
                                                                    │  └───────────────────┘  │
                                                                    │                         │
                                                                    │   bar EKS cluster        │
                                                                    │   Cilium ENI mode        │
                                                                    └─────────────────────────┘
```

## Demo Topology

The demo models a simplified e-commerce flow across two clusters.

`checkout` (foo cluster, Go/chi, port 8080) is the orchestrator. It receives external HTTP requests through the ALB and fans out to three backend services in the bar cluster over VPC Lattice:

- `inventory` (Go/chi, port 8081): checks item availability against DynamoDB
- `payment` (Python/FastAPI, port 8082): processes payment authorization
- `delivery` (Node.js/Fastify, port 8083): schedules delivery

None of the backend services are directly reachable from the internet. All cross-VPC calls from `checkout` go through VPC Lattice service endpoints, with SigV4 signing handled at the application level.

## Key Technologies

| Component | Version / Detail |
|---|---|
| Amazon EKS | 1.35 |
| Cilium | 1.19.1, ENI mode, `kubeProxyReplacement` enabled |
| AWS Gateway API Controller | v2.0.1 |
| AWS Load Balancer Controller | v3.1.0 |
| VPC Lattice | Service network with SigV4 (`UNSIGNED-PAYLOAD`) |
| Kubernetes Gateway API | `gateway.networking.k8s.io/v1` |
| Terraform | >= 1.x |
| Kustomize + Helm | Via `kubectl kustomize --enable-helm` |

## Prerequisites

- An AWS account with sufficient IAM permissions to create EKS clusters, VPCs, VPC Lattice resources, DynamoDB tables, and IAM roles
- Terraform >= 1.x
- `kubectl`
- AWS CLI, configured with credentials
- Docker (for building and pushing container images)
- `kustomize` is used via `kubectl kustomize --enable-helm` — no separate install needed

**Apple Silicon users:** all container images must be built for `linux/amd64`. The Makefile handles this automatically via `--platform linux/amd64`, but make sure Docker Desktop is configured to support cross-platform builds (Rosetta or QEMU).

## Quick Start

The Makefile is the single entry point for all operations. You can run each step individually or use `make deploy-all` to do everything in one shot.

### Step-by-step

**Single-command deployment**

```bash
make deploy-all
```

**1. Provision infrastructure**

```bash
make infra
```

This runs `terraform apply` inside `terraform/` and provisions both VPCs, EKS clusters, VPC Lattice service network, DynamoDB table, ECR repositories, and all required IAM roles.

**2. Load environment variables**

```bash
eval $(make env)
```

Exports Terraform outputs (cluster names, ECR URLs, VPC Lattice service endpoints, etc.) as shell environment variables. Required for subsequent steps.

**3. Configure kubectl contexts**

```bash
make configure-kubeconfig
```

Sets up `kubectl` contexts named `foo` and `bar` pointing to the respective EKS clusters.

**4. Build and push container images**

```bash
make build-images && make push-images
```

Builds all four service images for `linux/amd64` and pushes them to ECR.

**5. Deploy to both clusters**

```bash
make setup-all
```

Applies Kubernetes manifests to both clusters using a 2-phase strategy (see below). Installs Cilium, AWS controllers, and all application resources.

**6. Seed DynamoDB**

```bash
make seed-data
```

Populates the DynamoDB table with demo inventory items.

**7. Verify deployments**

```bash
make verify-all
```

Checks that all pods are running and services are healthy across both clusters.

**8. Run end-to-end test**

```bash
make e2e-test
```

Sends a test checkout request through the ALB and validates the full cross-VPC flow.

Runs all of the above steps in sequence. Useful for a clean environment.

## Directory Structure

```
.
├── terraform/              # All infrastructure as code (VPCs, EKS, Lattice, IAM, DynamoDB)
│   ├── envs/               # Per-environment variable files
│   ├── modules/            # Reusable Terraform modules
│   └── keypairs/           # SSH key pair resources
├── kubernetes/             # Kubernetes manifests
│   ├── base/               # Base Kustomize resources (shared across clusters)
│   └── overlays/           # Cluster-specific overlays (foo/, bar/)
├── apps/                   # Application source code
│   ├── checkout/           # Go/chi service (foo cluster)
│   ├── inventory/          # Go/chi service (bar cluster)
│   ├── payment/            # Python/FastAPI service (bar cluster)
│   └── delivery/           # Node.js/Fastify service (bar cluster)
├── docs/                   # Architecture notes and diagrams
├── .sisyphus/              # Operational notes, troubleshooting, and session logs
│   └── TROUBLESHOOTING.md  # Known issues and fixes
└── Makefile                # Single entry point for all operations
```

## Makefile Targets

### Infrastructure

| Target | Description |
|---|---|
| `make infra` | Run `terraform apply` to provision all AWS resources |
| `make infra-plan` | Run `terraform plan` (dry run) |
| `make infra-destroy` | Run `terraform destroy` to tear down all AWS resources |

### Environment

| Target | Description |
|---|---|
| `make env` | Print Terraform outputs as `export` statements (use with `eval`) |
| `make configure-kubeconfig` | Update kubeconfig for both `foo` and `bar` clusters |

### Container Images

| Target | Description |
|---|---|
| `make build-images` | Build all service images for `linux/amd64` |
| `make push-images` | Push all images to ECR |

### Kubernetes Setup

| Target | Description |
|---|---|
| `make setup-foo` | Deploy all resources to the `foo` cluster (2-phase) |
| `make setup-bar` | Deploy all resources to the `bar` cluster (2-phase) |
| `make setup-all` | Deploy to both clusters |
| `make seed-data` | Seed DynamoDB with demo inventory items |

### Verification

| Target | Description |
|---|---|
| `make verify-foo` | Check pod and service health on `foo` cluster |
| `make verify-bar` | Check pod and service health on `bar` cluster |
| `make verify-all` | Health check across both clusters |
| `make e2e-test` | Run end-to-end checkout flow test |

### Full Lifecycle

| Target | Description |
|---|---|
| `make deploy-all` | Full deployment: infra + images + k8s + seed + verify |
| `make teardown-all` | Remove all Kubernetes resources from both clusters |
| `make destroy-all` | Full teardown: k8s resources first, then `terraform destroy` |

## 2-Phase Apply Strategy

CRD-dependent resources like `Gateway`, `HTTPRoute`, `Ingress`, and `TargetGroupPolicy` can't be applied until their respective controllers (AWS Gateway API Controller, AWS Load Balancer Controller) are running and have registered their CRDs with the API server. Applying everything in one pass causes spurious errors.

To handle this cleanly, the Makefile splits each cluster's setup into two phases:

1. Phase 1: installs Cilium, controller Helm charts, and base CRD-free resources
2. Phase 2: waits for controllers to become ready, then applies Gateway API and Ingress resources

This is handled automatically by `make setup-foo`, `make setup-bar`, and `make setup-all`. You don't need to manage the ordering manually.

## Teardown

To remove only Kubernetes resources (keep AWS infrastructure):

```bash
make teardown-all
```

To tear down everything, including all AWS resources provisioned by Terraform:

```bash
make destroy-all
```

`destroy-all` removes Kubernetes resources first to allow AWS controllers to clean up VPC Lattice associations and load balancers before Terraform runs. Skipping this order can leave orphaned AWS resources.

---

This project is supported by [Algorix Corporation](https://algorix.io).
