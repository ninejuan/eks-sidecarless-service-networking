.PHONY: help infra infra-plan infra-destroy \
       install-crds-foo install-crds-bar \
       delete-cni-foo delete-cni-bar \
       apply-foo apply-bar \
       setup-foo setup-bar setup-all \
       teardown-foo teardown-bar teardown-all \
       verify-foo verify-bar verify-all \
       e2e-test

SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Tool aliases
# ---------------------------------------------------------------------------
KUBECTL_FOO := kubectl --context $(FOO_CONTEXT)
KUBECTL_BAR := kubectl --context $(BAR_CONTEXT)

# kubectl kustomize is used instead of standalone kustomize binary
KUSTOMIZE_FOO := kubectl kustomize --enable-helm kubernetes/overlays/foo
KUSTOMIZE_BAR := kubectl kustomize --enable-helm kubernetes/overlays/bar

# Gateway API CRD manifest (must match the version used by gateway-api-controller chart)
GATEWAY_API_CRD_URL := https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# ---------------------------------------------------------------------------
# Required environment variables
# ---------------------------------------------------------------------------
# FOO_CONTEXT                          — kubectl context for foo cluster
# BAR_CONTEXT                          — kubectl context for bar cluster
# AWS_ACCOUNT_ID                       — AWS account ID for ECR image references
# FOO_VPC_ID                           — VPC ID for foo cluster
# BAR_VPC_ID                           — VPC ID for bar cluster
# FOO_CLUSTER_NAME                     — EKS cluster name for foo
# BAR_CLUSTER_NAME                     — EKS cluster name for bar
# FOO_GATEWAY_API_CONTROLLER_ROLE_ARN  — IAM role ARN for foo Gateway API Controller
# BAR_GATEWAY_API_CONTROLLER_ROLE_ARN  — IAM role ARN for bar Gateway API Controller
# CHECKOUT_ROLE_ARN                    — IAM role ARN for checkout service (IRSA)
# INVENTORY_ROLE_ARN                   — IAM role ARN for inventory service (IRSA)
# INVENTORY_LATTICE_DNS                — Lattice DNS for inventory service
# PAYMENT_LATTICE_DNS                  — Lattice DNS for payment service
# DELIVERY_LATTICE_DNS                 — Lattice DNS for delivery service

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

infra: ## Apply Terraform infrastructure
	cd terraform/envs/demo && terraform init -upgrade && terraform apply

infra-plan: ## Plan Terraform changes
	cd terraform/envs/demo && terraform init -upgrade && terraform plan

infra-destroy: ## Destroy Terraform infrastructure
	cd terraform/envs/demo && terraform destroy

# ---------------------------------------------------------------------------
# Gateway API CRDs (must be installed before controller or Gateway resources)
# ---------------------------------------------------------------------------

install-crds-foo: ## Install Gateway API CRDs on foo cluster
	$(KUBECTL_FOO) apply -f $(GATEWAY_API_CRD_URL)

install-crds-bar: ## Install Gateway API CRDs on bar cluster
	$(KUBECTL_BAR) apply -f $(GATEWAY_API_CRD_URL)

# ---------------------------------------------------------------------------
# Kubernetes — foo cluster (checkout)
# ---------------------------------------------------------------------------

delete-cni-foo: ## Delete default VPC CNI and kube-proxy from foo cluster
	$(KUBECTL_FOO) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_FOO) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-foo: ## Apply Kustomize manifests to foo cluster
	$(KUSTOMIZE_FOO) | envsubst | $(KUBECTL_FOO) apply --server-side -f -

setup-foo: delete-cni-foo install-crds-foo apply-foo ## Full setup for foo cluster (delete CNI → CRDs → apply)

teardown-foo: ## Remove all managed resources from foo cluster
	$(KUSTOMIZE_FOO) | envsubst | $(KUBECTL_FOO) delete --ignore-not-found -f -

# ---------------------------------------------------------------------------
# Kubernetes — bar cluster (inventory, payment, delivery)
# ---------------------------------------------------------------------------

delete-cni-bar: ## Delete default VPC CNI and kube-proxy from bar cluster
	$(KUBECTL_BAR) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_BAR) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-bar: ## Apply Kustomize manifests to bar cluster
	$(KUSTOMIZE_BAR) | envsubst | $(KUBECTL_BAR) apply --server-side -f -

setup-bar: delete-cni-bar install-crds-bar apply-bar ## Full setup for bar cluster (delete CNI → CRDs → apply)

teardown-bar: ## Remove all managed resources from bar cluster
	$(KUSTOMIZE_BAR) | envsubst | $(KUBECTL_BAR) delete --ignore-not-found -f -

# ---------------------------------------------------------------------------
# Combined
# ---------------------------------------------------------------------------

setup-all: setup-foo setup-bar ## Full setup for both clusters

teardown-all: teardown-foo teardown-bar ## Teardown both clusters

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

verify-foo: ## Verify foo cluster health (pods, gateway, routes)
	@echo "=== Pods ==="
	$(KUBECTL_FOO) get pods -A --field-selector=status.phase!=Running 2>/dev/null || true
	@echo "=== GatewayClass ==="
	$(KUBECTL_FOO) get gatewayclass
	@echo "=== Gateway ==="
	$(KUBECTL_FOO) get gateway -n aws-application-networking-system
	@echo "=== HTTPRoutes ==="
	$(KUBECTL_FOO) get httproute -A

verify-bar: ## Verify bar cluster health (pods, gateway, routes)
	@echo "=== Pods ==="
	$(KUBECTL_BAR) get pods -A --field-selector=status.phase!=Running 2>/dev/null || true
	@echo "=== GatewayClass ==="
	$(KUBECTL_BAR) get gatewayclass
	@echo "=== Gateway ==="
	$(KUBECTL_BAR) get gateway -n aws-application-networking-system
	@echo "=== HTTPRoutes ==="
	$(KUBECTL_BAR) get httproute -A

verify-all: verify-foo verify-bar ## Verify both clusters

# ---------------------------------------------------------------------------
# E2E Test
# ---------------------------------------------------------------------------

e2e-test: ## Run E2E test via checkout (requires FOO_CONTEXT, checkout pod running)
	$(KUBECTL_FOO) exec -n checkout deploy/checkout -c checkout -- \
		wget -qO- http://localhost:8080/v1/checkout/orders \
		--header='Content-Type: application/json' \
		--post-data='{"orderId":"e2e-test","sku":"ITEM-A","quantity":1,"amount":100,"currency":"KRW","address":"Seoul"}'
