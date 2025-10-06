output "vpc_id" {
  value = aws_vpc.vpc_1.id
}

output "subnet_1_id" {
  value = aws_subnet.subnet_1.id
}

output "subnet_2_id" {
  value = aws_subnet.subnet_2.id
}

output "subnet_3_id" {
  value = aws_subnet.subnet_3.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat_gw.id
}

output "igw_id" {
  value = aws_internet_gateway.internet_gateway.id
}
