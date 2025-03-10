output "ec2_instance_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.moriarty_runtime[*].public_ip
}