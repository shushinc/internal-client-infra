data "aws_availability_zones" "available" {}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws
}


locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    is_terraform = "yes"
    environment  = "sandbox"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.cluster_version

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.11.3-eksbuild.2"
    }
    kube-proxy = {
      addon_version = "v1.31.2-eksbuild.3"
    }
    vpc-cni = {
      addon_version = "v1.19.0-eksbuild.1",
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    eks-pod-identity-agent = {
      addon_version = "v1.3.4-eksbuild.1"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = var.eks_managed_node_groups

  # cluster_tags = merge(local.tags, {
  #   NOTE - only use this option if you are using "attach_cluster_primary_security_group"
  #   and you know what you're doing. In this case, you can remove the "node_security_group_tags" below.
  #  "karpenter.sh/discovery" = local.name
  # })

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks_cluster_name
  }

  tags = local.tags
}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name                    = module.eks.cluster_name
  create_iam_role                 = true
  create_node_iam_role            = true
  enable_pod_identity             = true
  create_pod_identity_association = true

  namespace                     = "karpenter"
  queue_name                    = "karpenter_queue"
  iam_role_use_name_prefix      = false
  iam_role_name                 = "karpenter_controller"
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "karpenter_node"

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}


################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = var.eks_cluster_name
  }

  tags = local.tags
}


module "eks-pod-identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.2.1"

  name = "aws-lbc"

  attach_aws_lb_controller_policy = true

  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
  }

  associations = {
    ex-one = {
      cluster_name = module.eks.cluster_name
    }
  }

}
