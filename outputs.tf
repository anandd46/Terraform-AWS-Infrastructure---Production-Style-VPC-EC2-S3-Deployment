############################################
# outputs.tf
# Useful output values after `terraform apply`
############################################

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (null if NAT Gateway is disabled)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.nat[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public Elastic IP address of the NAT Gateway (null if disabled)"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "nat_instance_public_ip" {
  description = "Public Elastic IP address of the Free Tier NAT Instance (null if disabled)"
  value       = (!var.enable_nat_gateway && var.enable_nat_instance) ? aws_eip.nat_instance[0].public_ip : null
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "web_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web.id
}

output "private_security_group_id" {
  description = "ID of the private tier security group"
  value       = aws_security_group.private.id
}

output "bastion_instance_id" {
  description = "Instance ID of the Bastion Host"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Elastic IP address of the Bastion Host - use this to SSH in"
  value       = aws_eip.bastion.public_ip
}

output "public_web_instance_id" {
  description = "Instance ID of the public web server"
  value       = aws_instance.public_web.id
}

output "public_web_public_ip" {
  description = "Public IP address of the public web server"
  value       = aws_instance.public_web.public_ip
}

output "private_app_instance_id" {
  description = "Instance ID of the private application server"
  value       = aws_instance.private_app.id
}

output "private_app_private_ip" {
  description = "Private IP address of the private application server (reachable only via bastion)"
  value       = aws_instance.private_app.private_ip
}

output "ssh_to_bastion_command" {
  description = "Ready-to-use SSH command to connect to the Bastion Host"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_eip.bastion.public_ip}"
}

output "ssh_to_private_via_bastion_command" {
  description = "Ready-to-use SSH ProxyJump command to reach the private instance through the bastion"
  value       = "ssh -i ${var.key_pair_name}.pem -J ec2-user@${aws_eip.bastion.public_ip} ec2-user@${aws_instance.private_app.private_ip}"
}
