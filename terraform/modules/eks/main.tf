data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = merge(var.tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = merge(var.tags, { Name = "${var.cluster_name}-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS managed node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-sg" })
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  security_group_id        = aws_security_group.cluster.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "Allow API traffic from worker nodes"
}

resource "aws_security_group_rule" "cluster_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.cluster.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow control plane egress"
}

# --- Cluster → Node: kubelet API ---
resource "aws_security_group_rule" "node_ingress_cluster_kubelet" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "Kubelet API from control plane"
}

# --- Cluster → Node: HTTPS (webhook, metrics-server, etc.) ---
resource "aws_security_group_rule" "node_ingress_cluster_https" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "HTTPS webhooks and metrics from control plane"
}

# --- Cluster → Node: LBC webhook ---
resource "aws_security_group_rule" "node_ingress_cluster_webhook" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "LBC webhook from control plane"
}

# --- Cluster → Node: CoreDNS ---
resource "aws_security_group_rule" "node_ingress_cluster_coredns_tcp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "CoreDNS TCP from control plane"
}

resource "aws_security_group_rule" "node_ingress_cluster_coredns_udp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "CoreDNS UDP from control plane"
}

# --- Node ↔ Node: Cilium health checks ---
resource "aws_security_group_rule" "node_ingress_self_cilium_health" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "Cilium health checks between nodes"
}

# --- Node ↔ Node: Hubble relay ---
resource "aws_security_group_rule" "node_ingress_self_hubble" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 4244
  to_port                  = 4244
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "Hubble relay between nodes"
}

# --- Node ↔ Node: VXLAN (Cilium tunnel fallback) ---
resource "aws_security_group_rule" "node_ingress_self_vxlan" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  source_security_group_id = aws_security_group.node.id
  description              = "VXLAN encapsulation between nodes"
}

# --- Node ↔ Node: kubelet API (metrics, logs) ---
resource "aws_security_group_rule" "node_ingress_self_kubelet" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "Kubelet API between nodes"
}

# --- Node ↔ Node: CoreDNS ---
resource "aws_security_group_rule" "node_ingress_self_coredns_tcp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "CoreDNS TCP between nodes"
}

resource "aws_security_group_rule" "node_ingress_self_coredns_udp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = aws_security_group.node.id
  description              = "CoreDNS UDP between nodes"
}

# --- Node ↔ Node: application ports ---
resource "aws_security_group_rule" "node_ingress_self_app" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = 8080
  to_port                  = 8090
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  description              = "Application ports between nodes"
}

# --- Node ↔ Node: ICMP (path MTU discovery) ---
resource "aws_security_group_rule" "node_ingress_self_icmp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.node.id
  description              = "ICMP for path MTU discovery between nodes"
}

# --- VPC Lattice → Node: service traffic ---
data "aws_ec2_managed_prefix_list" "vpc_lattice" {
  name = "com.amazonaws.${var.region}.vpc-lattice"
}

resource "aws_security_group_rule" "node_ingress_vpc_lattice" {
  type              = "ingress"
  security_group_id = aws_security_group.node.id
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.vpc_lattice.id]
  description       = "VPC Lattice service traffic to pods"
}

resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.node.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow worker node egress"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version



  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
  }

  kubernetes_network_config {
    ip_family = "ipv4"
  }

  tags = merge(var.tags, { Name = var.cluster_name })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_security_group_rule.cluster_ingress_nodes,
    aws_security_group_rule.cluster_egress_all,
  ]
}

resource "aws_launch_template" "node" {
  name_prefix            = "${var.cluster_name}-ng-"
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.node.id]

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name                                        = "${var.cluster_name}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-ng" })
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_scaling_config.min_size
    max_size     = var.node_scaling_config.max_size
    desired_size = var.node_scaling_config.desired_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-default-node-group" })

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_security_group_rule.node_ingress_cluster_kubelet,
    aws_security_group_rule.node_ingress_cluster_https,
    aws_security_group_rule.node_ingress_self_cilium_health,
    aws_security_group_rule.node_egress_all,
  ]
}

data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = merge(var.tags, { Name = "${var.cluster_name}-oidc-provider" })
}

resource "aws_eks_access_entry" "admin" {
  count = var.enable_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
  tags          = merge(var.tags, { Name = "${var.cluster_name}-admin-access" })
}

resource "aws_eks_access_policy_association" "admin" {
  count = var.enable_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin[0].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
