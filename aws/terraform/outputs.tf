output "cluster_name" {
    value = var.cluster_name
}

output "primary_vpc_id" {
    value = module.vpc.vpc_id
}

output "secondary_vpc_id" {
    value = module.vpc_secondary.vpc_id
}

output "primary_azs" {
    value = module.vpc.azs
}

output "secondary_azs" {
    value = module.vpc_secondary.azs
}

output "primary_private_subnets" {
    value = module.vpc.private_subnets
}

output "secondary_private_subnets" {
    value = module.vpc_secondary.private_subnets
}

output "node_iam_role_arn" {
    value = module.eks.node_iam_role_arn
}
