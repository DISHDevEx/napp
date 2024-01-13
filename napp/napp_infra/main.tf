/*
Terraform configurations for all findr clusters.
*/

provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

##EKS module
##NAPP
module "napp" {
  source                                       = "git@github.com:DISHDevEx/iot.git//aws/modules/eks_cluster"
  flag_use_existing_vpc                        = true
  existing_vpc_id                              = var.existing_vpc_id
  flag_use_existing_subnet                     = true
  existing_subnet_ids                          = [var.existing_subnet_ids_1,var.existing_subnet_ids_2]
  flag_use_existing_subnet_route_table         = true
  existing_subnet_route_table_id               = var.existing_subnet_route_table_id
  flag_use_existing_eks_execution_role         = true
  existing_eks_iam_role_arn                    = var.existing_eks_iam_role_arn
  flag_use_existing_node_group_role            = true
  existing_node_group_iam_role_arn             = var.existing_node_group_iam_role_arn
  eks_cluster_name                             = var.eks_cluster_name_1
  eks_node_group_name                          = var.eks_node_group_name_1
  eks_node_capacity_type                       = "ON_DEMAND"
  eks_node_instance_types                      = [var.eks_node_instance_types_1]
  eks_node_desired_size                        = 1
  eks_node_max_size                            = 2
  eks_node_min_size                            = 1
  eks_node_max_unavailable                     = 1
}

#S3 module for NAPP
module "napp-s3" {
  source                  = "git@github.com:DISHDevEx/iot.git//aws/modules/s3"
  bucket_name             = var.bucket_name
  bucket_versioning       = var.bucket_versioning
  pass_bucket_policy_file = var.pass_bucket_policy_file
  bucket_policy_file_path = var.bucket_policy_file_path
}

# CoreDNS add-on for napp cluster
resource "aws_eks_addon" "napp_coredns" {
  cluster_name = "iot-napp"
  addon_name   = "coredns"
  addon_version= "v1.10.1-eksbuild.2"
  depends_on   = [module.napp]
}

# kube-proxy add-on for napp cluster
resource "aws_eks_addon" "napp_kube_proxy" {
  cluster_name = "iot-napp"
  addon_name   = "kube-proxy"
  addon_version= "v1.28.1-eksbuild.1"
  depends_on   = [module.napp]
}

# Amazon VPC CNI add-on for napp cluster
resource "aws_eks_addon" "napp_vpc_cni" {
  cluster_name = "iot-napp"
  addon_name   = "vpc-cni"
  addon_version= "v1.14.1-eksbuild.1"
  depends_on   = [module.napp]
}

# Amazon EBS CSI Driver add-on for napp cluster
resource "aws_eks_addon" "napp_ebs_csi" {
  cluster_name = "iot-napp"
  addon_name   = "aws-ebs-csi-driver"
  addon_version= "v1.25.0-eksbuild.1"
  depends_on   = [module.napp]
}


resource "aws_eks_node_group" "napp_upf_small_nodes" {
  cluster_name    = "iot-napp"
  node_group_name = "iot-napp-upf-small-nodes"
  node_role_arn   = var.existing_node_group_iam_role_arn
  subnet_ids      = [var.existing_subnet_ids_1,var.existing_subnet_ids_2]
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
}


resource "aws_eks_node_group" "napp_nodes" {
  cluster_name    = "iot-napp"
  node_group_name = "iot-napp-nodes"
  node_role_arn   = var.existing_node_group_iam_role_arn
  subnet_ids      = [var.existing_subnet_ids_1,var.existing_subnet_ids_2]
  instance_types = ["m4.xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
}