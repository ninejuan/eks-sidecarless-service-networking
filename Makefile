.PHONY: help infra infra-plan infra-destroy \
       install-crds-foo install-crds-bar install-crds-lbc-foo \
       delete-cni-foo delete-cni-bar \
       apply-foo apply-bar \
       setup-foo setup-bar setup-all \
       teardown-foo teardown-bar teardown-all \
       verify-foo verify-bar verify-all \
       env configure-kubeconfig lattice-dns e2e-test seed-data \
       ecr-login build-images push-images deploy-all destroy-all

SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Tool aliases
# ---------------------------------------------------------------------------
FOO_CONTEXT ?= foo
BAR_CONTEXT ?= bar
KUBECTL_FOO := kubectl --context $(FOO_CONTEXT)
KUBECTL_BAR := kubectl --context $(BAR_CONTEXT)

# kubectl kustomize is used instead of standalone kustomize binary
KUSTOMIZE_FOO := kubectl kustomize --enable-helm kubernetes/overlays/foo
KUSTOMIZE_BAR := kubectl kustomize --enable-helm kubernetes/overlays/bar

# envsubst leaves bare integers unquoted (e.g. value: 156041424727) which breaks
# server-side apply. This sed quotes any bare integer that appears as a YAML value.
# IMPORTANT: restrict envsubst to known variables only — unrestricted envsubst
# destroys nginx $host/$remote_addr and similar dollar-sign references.
# envsubst also leaves bare integers unquoted (e.g. value: 156041424727) which
# breaks server-side apply, so sed quotes them.
ENVSUBST := envsubst '$$AWS_ACCOUNT_ID $$AWS_REGION $$CHECKOUT_ROLE_ARN $$DELIVERY_LATTICE_DNS $$FOO_CLUSTER_NAME $$FOO_GATEWAY_API_CONTROLLER_ROLE_ARN $$FOO_LB_CONTROLLER_ROLE_ARN $$FOO_VPC_ID $$INVENTORY_LATTICE_DNS $$PAYMENT_LATTICE_DNS $$BAR_CLUSTER_NAME $$BAR_GATEWAY_API_CONTROLLER_ROLE_ARN $$BAR_VPC_ID $$INVENTORY_ROLE_ARN' | sed 's/\(value: \)\([0-9][0-9]*\)$$/\1"\2"/'

# Kinds that depend on CRDs or admission webhooks installed by controllers.
# Applied in Phase 2 (deferred) after controllers are ready.
# cert-manager handles webhook TLS lifecycle, so Certificate/Issuer stay in Phase 1.
DEFERRED_KINDS := TargetGroupPolicy|Gateway|HTTPRoute|Ingress

# split_yaml — portable (BSD + GNU awk) 3-way multi-doc YAML splitter.
# Splits a multi-doc YAML file into:
#   infra    — CNI (Cilium) + cert-manager resources (Phase 0)
#   base     — controllers, apps, CRDs (Phase 1)
#   deferred — Gateway API resources, Ingress, TargetGroupPolicy (Phase 2)
# Usage: awk -v infra=<path> -v base=<path> -v deferred=<path> "$$SPLIT_YAML_AWK" input.yaml
define SPLIT_YAML_AWK
BEGIN { kind=""; ns=""; name=""; buf="" }
/^---/ {
  if (buf != "") {
    if (ns == "cert-manager" || name ~ /cert-manager/) printf "%s", buf > infra;
    else if (ns == "cilium-secrets" || name ~ /^cilium/ || name ~ /^hubble/) printf "%s", buf > infra;
    else if (kind ~ /^($(DEFERRED_KINDS))$$/) printf "%s", buf > deferred;
    else printf "%s", buf > base;
  }
  buf = $$0 "\n"; kind = ""; ns = ""; name = ""; next
}
/^kind:/ { kind = $$2 }
/^  namespace:/ { if (ns == "") ns = $$2 }
/^  name:/ { if (name == "") name = $$2 }
{ buf = buf $$0 "\n" }
END {
  if (buf != "") {
    if (ns == "cert-manager" || name ~ /cert-manager/) printf "%s", buf > infra;
    else if (ns == "cilium-secrets" || name ~ /^cilium/ || name ~ /^hubble/) printf "%s", buf > infra;
    else if (kind ~ /^($(DEFERRED_KINDS))$$/) printf "%s", buf > deferred;
    else printf "%s", buf > base;
  }
}
endef
export SPLIT_YAML_AWK
GATEWAY_API_CRD_URL := https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/experimental-install.yaml

LBC_CRD_URL := https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.1.0/helm/aws-load-balancer-controller/crds/crds.yaml

# ---------------------------------------------------------------------------
# Container image settings
# ---------------------------------------------------------------------------
ECR_REGISTRY = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_PREFIX := summit-demo
APPS := checkout inventory payment delivery
PLATFORM := linux/amd64

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
# FOO_LB_CONTROLLER_ROLE_ARN           — IAM role ARN for foo AWS LB Controller
# BAR_GATEWAY_API_CONTROLLER_ROLE_ARN  — IAM role ARN for bar Gateway API Controller
# CHECKOUT_ROLE_ARN                    — IAM role ARN for checkout service (IRSA)
# INVENTORY_ROLE_ARN                   — IAM role ARN for inventory service (IRSA)
# INVENTORY_LATTICE_DNS                — Lattice DNS for inventory service (auto-populated by setup-all)
# PAYMENT_LATTICE_DNS                  — Lattice DNS for payment service (auto-populated by setup-all)
# DELIVERY_LATTICE_DNS                 — Lattice DNS for delivery service (auto-populated by setup-all)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

infra: ## Apply Terraform infrastructure
	cd terraform/envs/demo && terraform init -upgrade && terraform apply -auto-approve

infra-plan: ## Plan Terraform changes
	cd terraform/envs/demo && terraform init -upgrade && terraform plan

infra-destroy: ## Destroy Terraform infrastructure
	cd terraform/envs/demo && terraform destroy -auto-approve

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
	@echo "export FOO_LB_CONTROLLER_ROLE_ARN=$$($(TF_OUT) eks_foo_lb_controller_role_arn)"
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
# Container images — build and push to ECR
# ---------------------------------------------------------------------------

ecr-login: ## Authenticate Docker to ECR
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_REGISTRY)

build-images: ## Build all app images (linux/amd64)
	@for app in $(APPS); do \
		echo "==> Building $$app..."; \
		docker build --platform $(PLATFORM) -t $(ECR_REGISTRY)/$(IMAGE_PREFIX)/$$app:latest apps/$$app; \
	done

push-images: ecr-login ## Push all app images to ECR
	@for app in $(APPS); do \
		echo "==> Pushing $$app..."; \
		docker push $(ECR_REGISTRY)/$(IMAGE_PREFIX)/$$app:latest; \
	done

# ---------------------------------------------------------------------------
# Gateway API CRDs (must be installed before controller or Gateway resources)
# ---------------------------------------------------------------------------

install-crds-foo: ## Install Gateway API CRDs on foo cluster
	$(KUBECTL_FOO) apply -f $(GATEWAY_API_CRD_URL)

install-crds-bar: ## Install Gateway API CRDs on bar cluster
	$(KUBECTL_BAR) apply -f $(GATEWAY_API_CRD_URL)

install-crds-lbc-foo: ## Install AWS LB Controller CRDs on foo cluster
	$(KUBECTL_FOO) apply -f $(LBC_CRD_URL)

# ---------------------------------------------------------------------------
# Kubernetes — foo cluster (checkout)
# ---------------------------------------------------------------------------

delete-cni-foo: ## Delete default VPC CNI and kube-proxy from foo cluster
	$(KUBECTL_FOO) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_FOO) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-foo: ## Apply Kustomize manifests to foo cluster (3-phase: infra → controllers → deferred)
	@$(KUBECTL_FOO) create namespace aws-application-networking-system --dry-run=client -o yaml | $(KUBECTL_FOO) apply -f -
	@$(KUBECTL_FOO) create namespace cert-manager --dry-run=client -o yaml | $(KUBECTL_FOO) apply -f -
	@TMPDIR=$$(mktemp -d) && trap 'rm -rf $$TMPDIR' EXIT && \
	$(KUSTOMIZE_FOO) | $(ENVSUBST) > $$TMPDIR/all.yaml && \
	awk -v infra=$$TMPDIR/infra.yaml -v base=$$TMPDIR/base.yaml -v deferred=$$TMPDIR/deferred.yaml "$$SPLIT_YAML_AWK" $$TMPDIR/all.yaml && \
	echo '    Phase 0: Applying infrastructure (Cilium + cert-manager)...' && \
	$(KUBECTL_FOO) apply --server-side -f $$TMPDIR/infra.yaml && \
	echo '    Waiting for Cilium...' && \
	$(KUBECTL_FOO) rollout status daemonset/cilium -n kube-system --timeout=300s && \
	$(KUBECTL_FOO) rollout status deployment/cilium-operator -n kube-system --timeout=120s && \
	echo '    Waiting for cert-manager...' && \
	$(KUBECTL_FOO) rollout status deployment/cert-manager -n cert-manager --timeout=120s && \
	$(KUBECTL_FOO) rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s && \
	$(KUBECTL_FOO) rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s && \
	echo '    Phase 1: Applying base resources (CRDs, controllers, apps)...' && \
	$(KUBECTL_FOO) apply --server-side -f $$TMPDIR/base.yaml && \
	echo '    Waiting for Gateway API Controller...' && \
	$(KUBECTL_FOO) rollout status deployment/gateway-api-controller-aws-gateway-controller-chart -n aws-application-networking-system --timeout=180s && \
	echo '    Waiting for AWS LB Controller...' && \
	$(KUBECTL_FOO) rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s && \
	echo '    Phase 2: Applying deferred resources (Gateway, HTTPRoutes, Ingress, webhooks)...' && \
	$(KUBECTL_FOO) apply --server-side -f $$TMPDIR/deferred.yaml

setup-foo: delete-cni-foo install-crds-foo install-crds-lbc-foo apply-foo ## Full setup for foo cluster (delete CNI → CRDs → apply)

teardown-foo: ## Remove all managed resources from foo cluster (ordered to prevent orphans)
	@echo "==> [foo] Step 1: Deleting Ingress (triggers ALB cleanup by LBC)..."
	$(KUBECTL_FOO) delete ingress checkout-alb -n checkout --ignore-not-found --timeout=60s || true
	@echo "==> [foo] Step 2: Deleting HTTPRoutes and Gateway (triggers Lattice cleanup)..."
	$(KUBECTL_FOO) delete httproute --all -A --ignore-not-found --timeout=60s || true
	$(KUBECTL_FOO) delete gateway --all -A --ignore-not-found --timeout=60s || true
	@echo "    Waiting 30s for controllers to reconcile deletions..."
	@sleep 30
	@echo "==> [foo] Step 3: Removing finalizers from stuck resources (if any)..."
	@for kind in gateway httproute ingress; do \
	  for res in $$($(KUBECTL_FOO) get $$kind -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {end}' 2>/dev/null); do \
	    ns=$${res%%/*}; name=$${res##*/}; \
	    echo "    Removing finalizer from $$kind/$$name in $$ns"; \
	    $(KUBECTL_FOO) patch $$kind $$name -n $$ns --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true; \
	  done; \
	done
	@echo "==> [foo] Step 4: Deleting remaining resources..."
	$(KUSTOMIZE_FOO) | $(ENVSUBST) | $(KUBECTL_FOO) delete --ignore-not-found -f - || true

# ---------------------------------------------------------------------------
# Kubernetes — bar cluster (inventory, payment, delivery)
# ---------------------------------------------------------------------------

delete-cni-bar: ## Delete default VPC CNI and kube-proxy from bar cluster
	$(KUBECTL_BAR) delete daemonset aws-node -n kube-system --ignore-not-found
	$(KUBECTL_BAR) delete daemonset kube-proxy -n kube-system --ignore-not-found

apply-bar: ## Apply Kustomize manifests to bar cluster (2-phase: infra+base → controller ready → deferred)
	@$(KUBECTL_BAR) create namespace aws-application-networking-system --dry-run=client -o yaml | $(KUBECTL_BAR) apply -f -
	@TMPDIR=$$(mktemp -d) && trap 'rm -rf $$TMPDIR' EXIT && \
	$(KUSTOMIZE_BAR) | $(ENVSUBST) > $$TMPDIR/all.yaml && \
	touch $$TMPDIR/infra.yaml && \
	awk -v infra=$$TMPDIR/infra.yaml -v base=$$TMPDIR/base.yaml -v deferred=$$TMPDIR/deferred.yaml "$$SPLIT_YAML_AWK" $$TMPDIR/all.yaml && \
	echo '    Phase 0: Applying infrastructure (Cilium)...' && \
	if [ -s $$TMPDIR/infra.yaml ]; then \
	  $(KUBECTL_BAR) apply --server-side -f $$TMPDIR/infra.yaml && \
	  echo '    Waiting for Cilium...' && \
	  $(KUBECTL_BAR) rollout status daemonset/cilium -n kube-system --timeout=300s && \
	  $(KUBECTL_BAR) rollout status deployment/cilium-operator -n kube-system --timeout=120s; \
	else \
	  echo '    (no infra resources)'; \
	fi && \
	echo '    Phase 1: Applying base resources (CRDs, controllers, apps)...' && \
	$(KUBECTL_BAR) apply --server-side -f $$TMPDIR/base.yaml && \
	echo '    Waiting for Gateway API Controller...' && \
	$(KUBECTL_BAR) rollout status deployment/gateway-api-controller-aws-gateway-controller-chart -n aws-application-networking-system --timeout=180s && \
	echo '    Phase 2: Applying deferred resources (Gateway, HTTPRoutes, TargetGroupPolicy)...' && \
	$(KUBECTL_BAR) apply --server-side -f $$TMPDIR/deferred.yaml

setup-bar: delete-cni-bar install-crds-bar apply-bar ## Full setup for bar cluster (delete CNI → CRDs → apply)

teardown-bar: ## Remove all managed resources from bar cluster (ordered to prevent orphans)
	@echo "==> [bar] Step 1: Deleting HTTPRoutes and Gateway (triggers Lattice cleanup)..."
	$(KUBECTL_BAR) delete httproute --all -A --ignore-not-found --timeout=60s || true
	$(KUBECTL_BAR) delete gateway --all -A --ignore-not-found --timeout=60s || true
	@echo "    Waiting 30s for Gateway Controller to reconcile Lattice deletions..."
	@sleep 30
	@echo "==> [bar] Step 2: Removing finalizers from stuck resources (if any)..."
	@for kind in gateway httproute; do \
	  for res in $$($(KUBECTL_BAR) get $$kind -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {end}' 2>/dev/null); do \
	    ns=$${res%%/*}; name=$${res##*/}; \
	    echo "    Removing finalizer from $$kind/$$name in $$ns"; \
	    $(KUBECTL_BAR) patch $$kind $$name -n $$ns --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true; \
	  done; \
	done
	@echo "==> [bar] Step 3: Deleting remaining resources..."
	$(KUSTOMIZE_BAR) | $(ENVSUBST) | $(KUBECTL_BAR) delete --ignore-not-found -f - || true

# ---------------------------------------------------------------------------
# Combined — orchestrated setup with Lattice DNS auto-injection
# ---------------------------------------------------------------------------

setup-all: ## Full setup: bar first → wait for Lattice DNS → foo with DNS injected
	@echo "==> Step 1/5: Setting up bar cluster (inventory, payment, delivery)..."
	$(MAKE) setup-bar
	@echo "==> Step 2/5: Waiting for Gateway API Controller to become ready on bar..."
	$(KUBECTL_BAR) rollout status deployment/gateway-api-controller-aws-gateway-controller-chart -n aws-application-networking-system --timeout=180s
	@echo "==> Step 3/5: Waiting for Lattice DNS assignment (up to 240s)..."
	@LATTICE_READY=false; \
	for i in $$(seq 1 48); do \
		INVENTORY=$$($(KUBECTL_BAR) get httproute inventory -n inventory -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}' 2>/dev/null); \
		PAYMENT=$$($(KUBECTL_BAR) get httproute payment -n payment -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}' 2>/dev/null); \
		DELIVERY=$$($(KUBECTL_BAR) get httproute delivery -n delivery -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}' 2>/dev/null); \
		if [ -n "$$INVENTORY" ] && [ -n "$$PAYMENT" ] && [ -n "$$DELIVERY" ]; then \
			echo "    Lattice DNS assigned."; \
			LATTICE_READY=true; \
			break; \
		fi; \
		echo "    Waiting... ($$((i * 5))s)"; \
		sleep 5; \
	done; \
	if [ "$$LATTICE_READY" != "true" ]; then \
		echo "ERROR: Lattice DNS was not assigned within 240s. Check Gateway API Controller logs."; \
		exit 1; \
	fi
	@echo "==> Step 4/5: Setting up foo cluster (checkout)..."
	$(MAKE) setup-foo
	@echo "==> Step 5/5: Re-applying foo with Lattice DNS values..."
	@export INVENTORY_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute inventory -n inventory -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}') && \
	export PAYMENT_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute payment -n payment -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}') && \
	export DELIVERY_LATTICE_DNS=$$($(KUBECTL_BAR) get httproute delivery -n delivery -o jsonpath='{.metadata.annotations.application-networking\.k8s\.aws/lattice-assigned-domain-name}') && \
	echo "    INVENTORY_LATTICE_DNS=$$INVENTORY_LATTICE_DNS" && \
	echo "    PAYMENT_LATTICE_DNS=$$PAYMENT_LATTICE_DNS" && \
	echo "    DELIVERY_LATTICE_DNS=$$DELIVERY_LATTICE_DNS" && \
	TMPDIR=$$(mktemp -d) && trap 'rm -rf $$TMPDIR' EXIT && \
	$(KUSTOMIZE_FOO) | $(ENVSUBST) > $$TMPDIR/all.yaml && \
	touch $$TMPDIR/infra.yaml && \
	awk -v infra=$$TMPDIR/infra.yaml -v base=$$TMPDIR/base.yaml -v deferred=$$TMPDIR/deferred.yaml "$$SPLIT_YAML_AWK" $$TMPDIR/all.yaml && \
	echo '    Applying base resources...' && \
	$(KUBECTL_FOO) apply --server-side -f $$TMPDIR/base.yaml && \
	echo '    Waiting for LB Controller...' && \
	$(KUBECTL_FOO) rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s && \
	echo '    Applying deferred resources (Gateway, HTTPRoutes, Ingress, webhooks)...' && \
	$(KUBECTL_FOO) apply --server-side -f $$TMPDIR/deferred.yaml
	@echo "==> Setup complete. Run 'make verify-all' to check cluster health."

teardown-all: teardown-foo teardown-bar ## Teardown both clusters

destroy-all: ## Full teardown: kubernetes resources → terraform infrastructure
	@echo "============================================================"
	@echo " EKS Sidecarless Service Networking — Full Destroy"
	@echo "============================================================"
	@echo ""
	@echo "==> Phase 1: Tearing down Kubernetes resources..."
	$(MAKE) teardown-all
	@echo ""
	@echo "==> Phase 2: Destroying Terraform infrastructure..."
	$(MAKE) infra-destroy
	@echo ""
	@echo "============================================================"
	@echo " All resources destroyed."
	@echo "============================================================"

# ---------------------------------------------------------------------------
# Full deployment — single command from infra to running services
# ---------------------------------------------------------------------------

deploy-all: ## Full deployment: infra → images → kubernetes (single command)
	@echo "============================================================"
	@echo " EKS Sidecarless Service Networking — Full Deployment"
	@echo "============================================================"
	@echo ""
	@echo "==> Phase 1: Terraform infrastructure..."
	$(MAKE) infra
	@echo ""
	@echo "==> Phase 2: Loading environment variables..."
	@eval $$($(MAKE) env) && \
	echo "" && \
	echo "==> Phase 3: Configuring kubeconfig..." && \
	$(MAKE) configure-kubeconfig && \
	echo "" && \
	echo "==> Phase 4: Building and pushing container images..." && \
	$(MAKE) build-images && \
	$(MAKE) push-images && \
	echo "" && \
	echo "==> Phase 5: Deploying to Kubernetes clusters..." && \
	$(MAKE) setup-all && \
	echo "" && \
	echo "==> Phase 6: Seeding demo data..." && \
	$(MAKE) seed-data && \
	echo "" && \
	echo "==> Phase 7: Verification..." && \
	$(MAKE) verify-all && \
	echo "" && \
	echo "============================================================" && \
	echo " Deployment complete!" && \
	echo "============================================================" && \
	echo "" && \
	ALB_DNS=$$($(KUBECTL_FOO) get ingress checkout-alb -n checkout -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null) && \
	if [ -n "$$ALB_DNS" ]; then \
	  echo " Checkout API endpoint:"; \
	  echo "   http://$$ALB_DNS/v1/checkout/orders"; \
	  echo ""; \
	  echo " Try it:"; \
	  echo "   curl -s -X POST http://$$ALB_DNS/v1/checkout/orders \\"; \
	  echo "     -H 'Content-Type: application/json' \\"; \
	  echo "     -d '{\"orderId\":\"test-001\",\"sku\":\"ITEM-A\",\"quantity\":1,\"amount\":100,\"currency\":\"KRW\",\"address\":\"Seoul\"}'"; \
	else \
	  echo " ALB endpoint not yet available. Run:"; \
	  echo "   kubectl --context foo get ingress -n checkout"; \
	fi && \
	echo "" && \
	echo " Run 'make e2e-test' for full flow verification." && \
	echo "============================================================"

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

# ---------------------------------------------------------------------------
# Seed Data — populate DynamoDB with demo inventory items
# ---------------------------------------------------------------------------

DYNAMODB_TABLE := summit-demo-inventory-items

seed-data: ## Seed DynamoDB with demo inventory items
	@echo "==> Seeding DynamoDB table $(DYNAMODB_TABLE) with demo items..."
	@aws dynamodb batch-write-item --region $(AWS_REGION) --request-items '{"$(DYNAMODB_TABLE)": [ \
	  {"PutRequest": {"Item": {"sku": {"S": "ITEM-A"}, "available_quantity": {"N": "1000"}}}}, \
	  {"PutRequest": {"Item": {"sku": {"S": "ITEM-B"}, "available_quantity": {"N": "500"}}}}, \
	  {"PutRequest": {"Item": {"sku": {"S": "ITEM-C"}, "available_quantity": {"N": "250"}}}}, \
	  {"PutRequest": {"Item": {"sku": {"S": "DEMO-001"}, "available_quantity": {"N": "9999"}}}} \
	]}' > /dev/null
	@echo "    Seeded 4 items: ITEM-A(1000), ITEM-B(500), ITEM-C(250), DEMO-001(9999)"
