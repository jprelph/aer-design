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

resource "aws_rds_global_cluster" "events" {
  global_cluster_identifier = "global-events"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.09.0"
  database_name             = "events_db"
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

# Primary Aurora Cluster

resource "aws_db_subnet_group" "events_primary" {
  provider   = aws.primary
  name       = "events"
  subnet_ids = slice(data.aws_availability_zones.available_primary.names, 0, 3)
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  cluster_identifier        = "events-primary-cluster"
  master_username           = "username"
  master_password           = "somepass123"
  database_name             = "events_db"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_primary.name
}

resource "aws_rds_cluster_instance" "primary" {
  provider             = aws.primary
  engine               = aws_rds_global_cluster.events.engine
  engine_version       = aws_rds_global_cluster.events.engine_version
  identifier           = "events-primary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = "db.serverless"
  db_subnet_group_name = aws_db_subnet_group.events_primary.name
}

# Secondary Aurora Cluster

resource "aws_db_subnet_group" "events_secondary" {
  provider   = aws.secondary
  name       = "events"
  subnet_ids = slice(data.aws_availability_zones.available_secondary.names, 0, 3)
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  cluster_identifier        = "events-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_secondary.name
  enable_global_write_forwarding = true

  lifecycle {
    ignore_changes = [
      replication_source_identifier
    ]
  }
  depends_on = [
    aws_rds_cluster_instance.primary
  ]
}

resource "aws_rds_cluster_instance" "secondary" {
  provider             = aws.secondary
  engine               = aws_rds_global_cluster.events.engine
  engine_version       = aws_rds_global_cluster.events.engine_version
  identifier           = "events-secondary-cluster-instance"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = "db.serverless"
  db_subnet_group_name = aws_db_subnet_group.events_secondary.name
}