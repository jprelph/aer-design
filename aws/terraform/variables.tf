variable "region" {
  type = string
}

variable "sec_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "primary_cidr" {
  type = string
}

variable "secondary_cidr" {
  type = string
}

variable "primary_vpc_private" {
 type = list(string) 
}
variable "primary_vpc_public" {
 type = list(string) 
}
variable "secondary_vpc_private" {
 type = list(string) 
}
variable "secondary_vpc_public" {
 type = list(string) 
}

variable "dbUser" {
  type = string
}

variable "dbPassword" {
  type = string
}

variable "dbName" {
  type = string
}