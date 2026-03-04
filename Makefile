.PHONY: help infra infra-destroy setup-foo setup-bar setup-all teardown-foo teardown-bar teardown-all

SHELL := /bin/bash
KUSTOMIZE := kustomize build --enable-helm
KUBECTL_FOO := kubectl --context $(FOO_CONTEXT)
KUBECTL_BAR := kubectl --context $(BAR_CONTEXT)

# Required environment variables:
#   FOO_CONTEXT       — kubectl context for foo cluster
#   BAR_CONTEXT       — kubectl context for bar cluster
#   AWS_ACCOUNT_ID    — AWS account ID for ECR image references
#   FOO_GATEWAY_API_CONTROLLER_ROLE_ARN — IAM role ARN for foo Gateway API Controller
#   BAR_GATEWAY_API_CONTROLLER_ROLE_ARN — IAM role ARN for bar Gateway API Controller
#   INVENTORY_LATTICE_DNS  — Lattice-generated DNS for inventory service (e.g. http://inventory-xxx.xxx.vpc-lattice-xxx.on.aws)
#   PAYMENT_LATTICE_DNS    — Lattice-generated DNS for payment service
#   DELIVERY_LATTICE_DNS   — Lattice-generated DNS for delivery service

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
# Kubernetes — foo cluster (checkout)
# ---------------------------------------------------------------------------

delete-cni-foo: ## Delete default VPC CNI and kube-proxy from foo cluster
	$(KUBECTL_FOO) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_FOO) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-foo: ## Apply Kustomize manifests to foo cluster
	$(KUSTOMIZE) kubernetes/overlays/foo | envsubst | $(KUBECTL_FOO) apply --server-side -f -

setup-foo: delete-cni-foo apply-foo ## Full setup for foo cluster (delete CNI → apply manifests)

teardown-foo: ## Remove all managed resources from foo cluster
	$(KUSTOMIZE) kubernetes/overlays/foo | envsubst | $(KUBECTL_FOO) delete --ignore-not-found -f -

# ---------------------------------------------------------------------------
# Kubernetes — bar cluster (inventory, payment, delivery)
# ---------------------------------------------------------------------------

delete-cni-bar: ## Delete default VPC CNI and kube-proxy from bar cluster
	$(KUBECTL_BAR) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_BAR) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-bar: ## Apply Kustomize manifests to bar cluster
	$(KUSTOMIZE) kubernetes/overlays/bar | envsubst | $(KUBECTL_BAR) apply --server-side -f -

setup-bar: delete-cni-bar apply-bar ## Full setup for bar cluster (delete CNI → apply manifests)

teardown-bar: ## Remove all managed resources from bar cluster
	$(KUSTOMIZE) kubernetes/overlays/bar | envsubst | $(KUBECTL_BAR) delete --ignore-not-found -f -

# ---------------------------------------------------------------------------
# Combined
# ---------------------------------------------------------------------------

setup-all: setup-foo setup-bar ## Full setup for both clusters

teardown-all: teardown-foo teardown-bar ## Teardown both clusters
