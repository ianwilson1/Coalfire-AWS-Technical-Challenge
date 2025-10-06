####### Network #######

# setting up what region that will get used
provider "aws" {
  region = "us-east-1"
}

# enable encryption for the root ebs volume
# added after initial infrastructure analysis
resource "aws_ebs_encryption_by_default" "example" {
  enabled = true
}

# setting up the vpc and with specific configuration
resource "aws_vpc" "vpc_1" {
    cidr_block = "10.1.0.0/16"

    tags = {
        name = "my_vpc_1" # make it easier to reference this vpc later
    }
}

# setting up application subnet as first subnet, should be private
resource "aws_subnet" "subnet_1" {
    cidr_block = "10.1.1.0/24"
    vpc_id = aws_vpc.vpc_1.id # this will tie it to my vpc
    availability_zone = "us-east-1a" # attach it to an AZ

    tags = {
        name = "application"
    }
}

# setting up the management subnet, this is the one that is accessible from the internet
resource "aws_subnet" "subnet_2" {
    cidr_block = "10.1.2.0/24"
    vpc_id = aws_vpc.vpc_1.id
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true # needed for any subnet that has access to the internet

    tags = {
        name = "management"
    }
}

# backend subnet, also not accessible from the internet
resource "aws_subnet" "subnet_3" {
    cidr_block = "10.1.3.0/24"
    vpc_id = aws_vpc.vpc_1.id
    availability_zone = "us-east-1b"

    tags = {
        name = "backend"
    }
}

# establish an internet gateway and attach it to the vpc being used
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc_1.id

    tags = {
        name = "igw"
    }
}

# allocate elastic IP for NAT Gateway
# added in after initial analysis of infrastructure
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT gateway for the management subnet (this one is public)
# added in after initial analysis of infrastructure
resource "aws_nat_gateway" "nat_gw" {
  connectivity_type = "public"
  subnet_id = aws_subnet.subnet_2.id # management subnet
  allocation_id = aws_eip.nat_eip.id
  

  tags = {
    name = "nat_gateway"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
}

# private route table to route internet traffic through the NAT gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_1.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
     name = "private_rt"
  }
}

# this will associate the private route table with application subnet so it can install apache
resource "aws_route_table_association" "app_private_rt" {
  subnet_id = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

# route table for public management subnet
resource "aws_route_table" "public_access" {
  vpc_id = aws_vpc.vpc_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    name = "public_rt"
  }
}

# associate the management subnet to the public access route table so it may reach the internet
resource "aws_route_table_association" "public_access_association" {
    subnet_id = aws_subnet.subnet_2.id

    route_table_id = aws_route_table.public_access.id
}