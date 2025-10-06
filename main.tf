####### Ian Wilson - Coalfire AWS Technical Challenge Oct 2025 #######


# setting up connection to AWS and the version for terraform
terraform {          
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


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

####### Compute #######

variable "my_ip_cidr" { 
    default = "192.168.137.1/32" 
}

# setting up security group for management ec2
resource "aws_security_group" "management_sg" {
    vpc_id = aws_vpc.vpc_1.id
    name = "management_sg"
    description = "management security group"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip_cidr]
    }

    tags = {
        name = "smanagement_sg"
    }
}

# security group for application load balancer
resource "aws_security_group" "alb_sg" {
    vpc_id = aws_vpc.vpc_1.id
    name = "alb_sg"
    description = "applicaton load balancer security group"

    tags = {
        name = "alb_sg"
    }
}

# ingress rules
resource "aws_security_group" "sg_1" {
    vpc_id = aws_vpc.vpc_1.id
    name = "sg_1"
    description = "security group 1"

    ingress { # allows SSH from the management ec2
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.management_sg.id]
    }

    ingress { # allows web traffic from the application load balancer
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    } 

    tags = {
        name = "sg_1"
    }
}

# creation of ec2 instance 
resource "aws_launch_template" "ec2_application" {
    image_id = "ami-052064a798f08f0d3" # retreived using aws ssm get-parameters..etc
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.sg_1.id]

    #IAM profile
    #added after analysis of infrastructure
    iam_instance_profile {
      name = aws_iam_instance_profile.ec2_profile.name
    }


    # script to install apache 
     user_data = base64encode(<<EOF
        #!/bin/bash
        set -e
        if command -v dnf >/dev/null; then
        dnf -y install httpd  # check to see if the system uses dnf
        else
        yum -y install httpd
        fi
        systemctl enable --now httpd
        echo "OK $(hostname -f)" > /var/www/html/index.html
        EOF
        )
}

# establishing the asg for the ec2
resource "aws_autoscaling_group" "app_asg" {
    min_size = 2
    max_size = 6
    desired_capacity = 2
    vpc_zone_identifier = [aws_subnet.subnet_1.id, aws_subnet.subnet_3.id]

    launch_template { # attach it to the ec2 instance
        id = aws_launch_template.ec2_application.id
        version = "$Latest"
    }

}

# make ec2 instance for management subnet
resource "aws_instance" "ec2_management" {
  ami = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet_2.id
  vpc_security_group_ids = [aws_security_group.management_sg.id]
  tags = { Name = "ec2_management" }
}

####### Supporting Infrastructure #######

# create the application load balancer
resource "aws_lb" "app_lb" {
  name = "app-load-balancer"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.subnet_1.id, aws_subnet.subnet_3.id] # use public/management subnet so internet can reach it

  tags = {
    Name = "app_lb"
  }
}

# target group for the ASG instances
resource "aws_lb_target_group" "app_tg" {
  name = "app-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "app_tg"
  }
}

# listener for the load balancer
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# connect autoscaling group to target group
resource "aws_autoscaling_attachment" "asg_attach_tg" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.id
  lb_target_group_arn = aws_lb_target_group.app_tg.arn
}

####### IAM #######
# added after initial analysis of infrastructure

# creating a super simple IAM role for ec2 instances
resource "aws_iam_role" "ec2_role" {
  name = "ec2_simple_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

# attaches the policy to the role
resource "aws_iam_role_policy_attachment" "policy_1" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" #linking to preexisting policy
}

# making an instance profile to attach to the ec2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

















