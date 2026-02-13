# EKS add-ons (Cilium, AWS Gateway API Controller, etc.) are managed
# outside Terraform via Helm/Kustomize to separate infrastructure
# lifecycle from application deployment lifecycle.
#
# See: kubernetes/controllers/ for Helm-based add-on installation.
