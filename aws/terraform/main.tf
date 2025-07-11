data "aws_availability_zones" "available_primary" {
  provider = aws.primary
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
data "aws_availability_zones" "available_secondary" {
  provider = aws.primary
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Primary VPC and EKS Cluster

module "vpc" {
  source   = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.primary
  }

  version  = "5.21.0"

  name = "events-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available_primary.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

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
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

# Secondary VPC and EKS Cluster 

module "vpc_secondary" {
  source   = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.secondary
  }

  version  = "5.21.0"

  name = "events-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available_secondary.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

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
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc_secondary.vpc_id
  subnet_ids = module.vpc_secondary.private_subnets
}