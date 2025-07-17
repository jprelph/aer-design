# Primary EKS Cluster

module "eks" {
  source   = "terraform-aws-modules/eks/aws"
  providers = {
    aws = aws.primary
  }
  version  = "20.37.1"
  cluster_name    = var.cluster_name
  cluster_version = "1.33"
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_compute_config = {
    enabled    = true
    node_pools = []
  }
  vpc_id     = module.vpc.vpc_id
  subnet_ids = setunion(
    module.vpc.public_subnets,
    module.vpc.private_subnets
  )
  node_iam_role_name = "${var.cluster_name}-node-role"
  node_iam_role_use_name_prefix = false
  node_iam_role_tags = {
    "cluster" = var.cluster_name
  }
  node_security_group_tags = {
    "cluster" = var.cluster_name
  }
}

# Create Access entry for EKS without default nodeclass and nodepool

resource "aws_eks_access_entry" "auto_mode" {
  provider = aws.primary
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"
}

resource "aws_eks_access_policy_association" "auto_mode" {
  provider = aws.primary
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = module.eks.node_iam_role_arn
  access_scope {
    type = "cluster"
  }
}

# Secondary EKS Cluster 

module "eks_secondary" {
  source   = "terraform-aws-modules/eks/aws"
  providers = {
    aws = aws.secondary
  }
  version  = "20.37.1"
  cluster_name    = var.cluster_name
  cluster_version = "1.33"
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_compute_config = {
    enabled    = true
    node_pools = []
  }
  vpc_id     = module.vpc_secondary.vpc_id
  subnet_ids = setunion(
    module.vpc_secondary.public_subnets,
    module.vpc_secondary.private_subnets
  )
  create_node_iam_role = false
  node_security_group_tags = {
    "cluster" = var.cluster_name
  }
}

# Create Access entry for EKS without default nodeclass and nodepool

resource "aws_eks_access_entry" "auto_mode_secondary" {
  provider = aws.secondary
  cluster_name  = module.eks_secondary.cluster_name
  principal_arn = module.eks.node_iam_role_arn
  type          = "EC2"
}

resource "aws_eks_access_policy_association" "auto_mode_secondary" {
  provider = aws.secondary
  cluster_name  = module.eks_secondary.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = module.eks.node_iam_role_arn
  access_scope {
    type = "cluster"
  }
}