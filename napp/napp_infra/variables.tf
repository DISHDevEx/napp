#Variables for root module
variable "aws_region" {
  description = "AWS region name"
  type        = string
  default     = "us-east-1"
}
variable "aws_access_key" {
  description = "AWS account access key"
  type        = string
  default     = null
  sensitive   = true
}
variable "aws_secret_key" {
  description = "AWS account secret key"
  type        = string
  default     = null
  sensitive   = true
}
variable "aws_session_token" {
  description = "AWS account session token"
  type        = string
  default     = null
  sensitive   = true
}
variable "profile" {
  description = "AWS account - credentials profile name"
  type        = string
  default     = null
  sensitive   = true
}

#Backend variables
variable "backend_bucket_name" {
  description = "Backend S3 bucket name to store the Terraform state file"
  type        = string
  default     = null
  sensitive   = true
}
variable "backend_bucket_key" {
  description = "Backend S3 file to store the Terraform state file"
  type        = string
  default     = null
  sensitive   = true
}
variable "backend_dynamodb_table_name" {
  description = "Backend Dynamodb table name to store the Terraform state lock"
  type        = string
  default     = null
  sensitive   = true
}

#napp cluster variables
variable "existing_subnet_route_table_id" {
  description = "route table id"
  type        = string
  default     = null
  sensitive   = true
}
variable "existing_vpc_id" {
  description = "vpc id"
  type        = string
  default     = null
  sensitive   = true
}
variable "existing_subnet_ids_1" {
  description = "subnets 1"
  type        = string
  default     = null
  sensitive   = true
}
variable "existing_subnet_ids_2" {
  description = "subnets 2"
  type        = string
  default     = null
  sensitive   = true
}
variable "existing_eks_iam_role_arn" {
  description = "iam role for eks cluster"
  type        = string
  default     = null
  sensitive   = true
}
variable "existing_node_group_iam_role_arn" {
  description = "iam role for node groups"
  type        = string
  default     = null
  sensitive   = true
}
variable "eks_cluster_name_1" {
  description = "unique cluster name 1"
  type        = string
  default     = null
  sensitive   = true
}

variable "eks_node_group_name_1" {
  description = "unique node group name 1"
  type        = string
  default     = null
  sensitive   = true
}

variable "eks_node_instance_types_1" {
  description = "instance types"
  type        = string
  default     = null
  sensitive   = true
}


#napp s3 variables
variable "bucket_name" {
  description = "s3 bucket"
  type        = string
  default     = "dish-napp"
  sensitive   = true
}
variable "bucket_versioning" {
  description = "version"
  type        = string
  default     = "Enabled"
  sensitive   = true
}
variable "pass_bucket_policy_file" {
  description = "policy"
  type        = string
  default     = false
  sensitive   = true
}
variable "bucket_policy_file_path" {
  description = "policy file"
  type        = string
  default     = null
  sensitive   = true
}
