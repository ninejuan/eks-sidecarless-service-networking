.PHONY: help infra infra-plan infra-destroy \
       install-crds-foo install-crds-bar \
       delete-cni-foo delete-cni-bar \
       apply-foo apply-bar \
       setup-foo setup-bar setup-all \
       teardown-foo teardown-bar teardown-all \
       verify-foo verify-bar verify-all \
       env configure-kubeconfig lattice-dns e2e-test

SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Tool aliases
# ---------------------------------------------------------------------------
KUBECTL_FOO := kubectl --context $(FOO_CONTEXT)
KUBECTL_BAR := kubectl --context $(BAR_CONTEXT)

# kubectl kustomize is used instead of standalone kustomize binary
KUSTOMIZE_FOO := kubectl kustomize --enable-helm kubernetes/overlays/foo
KUSTOMIZE_BAR := kubectl kustomize --enable-helm kubernetes/overlays/bar

# envsubst leaves bare integers unquoted (e.g. value: 156041424727) which breaks
# server-side apply. This sed quotes any bare integer that appears as a YAML value.
ENVSUBST := envsubst | sed 's/\(value: \)\([0-9][0-9]*\)$$/\1"\2"/'

# Gateway API CRD manifest (must match the version used by gateway-api-controller chart)
GATEWAY_API_CRD_URL := https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# ---------------------------------------------------------------------------
# Required environment variables
# ---------------------------------------------------------------------------
# AWS_REGION                           — AWS region (from terraform output or default ap-northeast-2)
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
# Environment variable helper (extracts terraform outputs for kubernetes layer)
# ---------------------------------------------------------------------------
# Usage: eval $(make env)
# This populates all required env vars from terraform outputs + AWS CLI.

TF_DIR := terraform/envs/demo
TF_OUT = cd $(TF_DIR) && terraform output -raw
AWS_REGION := $(shell cd $(TF_DIR) && terraform output -raw region 2>/dev/null || echo ap-northeast-2)

env: ## Print export statements for all required env vars (usage: eval $$(make env))
	@echo "export FOO_CONTEXT=foo"
	@echo "export BAR_CONTEXT=bar"
	@echo "export AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text)"
	@echo "export FOO_VPC_ID=$$($(TF_OUT) vpc_foo_id)"
	@echo "export BAR_VPC_ID=$$($(TF_OUT) vpc_bar_id)"
	@echo "export FOO_CLUSTER_NAME=$$($(TF_OUT) eks_foo_cluster_name)"
	@echo "export BAR_CLUSTER_NAME=$$($(TF_OUT) eks_bar_cluster_name)"
	@echo "export FOO_GATEWAY_API_CONTROLLER_ROLE_ARN=$$($(TF_OUT) eks_foo_gateway_api_controller_role_arn)"
	@echo "export BAR_GATEWAY_API_CONTROLLER_ROLE_ARN=$$($(TF_OUT) eks_bar_gateway_api_controller_role_arn)"
	@echo "export CHECKOUT_ROLE_ARN=$$($(TF_OUT) checkout_role_arn)"
	@echo "export INVENTORY_ROLE_ARN=$$($(TF_OUT) inventory_role_arn)"
	@echo "export AWS_REGION=$$($(TF_OUT) region 2>/dev/null || echo ap-northeast-2)"

configure-kubeconfig: ## Configure kubectl contexts for foo and bar clusters (requires FOO/BAR_CLUSTER_NAME)
	aws eks update-kubeconfig --name $(FOO_CLUSTER_NAME) --region $(AWS_REGION) --alias foo
	aws eks update-kubeconfig --name $(BAR_CLUSTER_NAME) --region $(AWS_REGION) --alias bar
	@echo "kubectl contexts 'foo' and 'bar' configured."

lattice-dns: ## Print export statements for Lattice service DNS values (run after setup-all)
	@echo "export INVENTORY_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute inventory -n inventory -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}')"
	@echo "export PAYMENT_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute payment -n payment -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}')"
	@echo "export DELIVERY_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute delivery -n delivery -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}')"
	@echo "# Usage: eval \$$(make lattice-dns)"

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
	@# First apply may fail if CRDs are not yet registered; retry to apply CRs after CRD registration
	$(KUSTOMIZE_FOO) | $(ENVSUBST) | $(KUBECTL_FOO) apply --server-side -f - || \
	$(KUSTOMIZE_FOO) | $(ENVSUBST) | $(KUBECTL_FOO) apply --server-side -f -

setup-foo: delete-cni-foo install-crds-foo apply-foo ## Full setup for foo cluster (delete CNI → CRDs → apply)

teardown-foo: ## Remove all managed resources from foo cluster
	$(KUSTOMIZE_FOO) | $(ENVSUBST) | $(KUBECTL_FOO) delete --ignore-not-found -f -

# ---------------------------------------------------------------------------
# Kubernetes — bar cluster (inventory, payment, delivery)
# ---------------------------------------------------------------------------

delete-cni-bar: ## Delete default VPC CNI and kube-proxy from bar cluster
	$(KUBECTL_BAR) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_BAR) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-bar: ## Apply Kustomize manifests to bar cluster
	@# First apply may fail if CRDs are not yet registered; retry to apply CRs after CRD registration
	$(KUSTOMIZE_BAR) | $(ENVSUBST) | $(KUBECTL_BAR) apply --server-side -f - || \
	$(KUSTOMIZE_BAR) | $(ENVSUBST) | $(KUBECTL_BAR) apply --server-side -f -

setup-bar: delete-cni-bar install-crds-bar apply-bar ## Full setup for bar cluster (delete CNI → CRDs → apply)

teardown-bar: ## Remove all managed resources from bar cluster
	$(KUSTOMIZE_BAR) | $(ENVSUBST) | $(KUBECTL_BAR) delete --ignore-not-found -f -

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
