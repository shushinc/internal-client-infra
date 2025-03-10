# Values

aws_region       = "us-east-1"
vpc_name         = "sandbox-vpc"
eks_cluster_name = "eks-hudson"
cluster_version  = "1.31"
eks_managed_node_groups = {
  mgn0 = {
    instance_types = ["m5.large"]
    capacity_type  = "ON_DEMAND"
    min_size       = 2
    max_size       = 10
    desired_size   = 2
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs         = {
          volume_size           = 50
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 150
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }
}
