data "aws_availability_zones" "available_primary" {
  provider = aws.primary
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zones" "available_secondary" {
  provider = aws.secondary
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
  cidr = var.primary_cidr
  azs  = slice(data.aws_availability_zones.available_primary.names, 0, 3)
  private_subnets = var.primary_vpc_private
  public_subnets  = var.primary_vpc_public
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
  cidr = var.secondary_cidr
  azs  = slice(data.aws_availability_zones.available_secondary.names, 0, 3)
  private_subnets = var.secondary_vpc_private
  public_subnets  = var.secondary_vpc_public
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
  subnet_ids = module.vpc.private_subnets
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.primary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  engine_mode               = "provisioned"
  cluster_identifier        = "events-primary-cluster"
  master_username           = "username"
  master_password           = "somepass123"
  database_name             = "events_db"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_primary.name
  skip_final_snapshot       = true
  serverlessv2_scaling_configuration {
    max_capacity             = 2.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
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
  subnet_ids = module.vpc_secondary.private_subnets
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  engine                    = aws_rds_global_cluster.events.engine
  engine_version            = aws_rds_global_cluster.events.engine_version
  engine_mode               = "provisioned"
  cluster_identifier        = "events-secondary-cluster"
  global_cluster_identifier = aws_rds_global_cluster.events.id
  db_subnet_group_name      = aws_db_subnet_group.events_secondary.name
  skip_final_snapshot       = true
  serverlessv2_scaling_configuration {
    max_capacity             = 2.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
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

# Create VPC Peering to support Aurora Global Writer Endpoint

data "aws_caller_identity" "peer" {
  provider = aws.secondary
}

resource "aws_vpc_peering_connection" "peer" {
  provider = aws.primary

  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = module.vpc_secondary.vpc_id
  peer_owner_id = data.aws_caller_identity.peer.account_id
  peer_region   = var.sec_region
  auto_accept   = false
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider = aws.primary

  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the accepter.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

#Update route tables to support peering

resource "aws_route" "secondary_peer" {
  provider                  = aws.primary
  count                     = length(module.vpc.private_route_table_ids)
  route_table_id            = tolist(module.vpc.private_route_table_ids)[count.index]
  destination_cidr_block    = var.secondary_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "primary_peer" {
  provider                  = aws.secondary
  count                     = length(module.vpc_secondary.private_route_table_ids)
  route_table_id            = tolist(module.vpc_secondary.private_route_table_ids)[count.index]
  destination_cidr_block    = var.primary_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}