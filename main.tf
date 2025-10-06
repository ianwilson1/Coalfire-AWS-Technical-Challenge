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

# connect the network module
module "network" {
  source   = "./modules/network"
  vpc_cidr = "10.1.0.0/16"
  vpc_name = "my_vpc_1"
}

####### Compute #######

variable "my_ip_cidr" { 
    default = "192.168.137.1/32" 
}

# setting up security group for management ec2
resource "aws_security_group" "management_sg" {
    vpc_id = module.network.vpc_id
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
    vpc_id = module.network.vpc_id
    name = "alb_sg"
    description = "applicaton load balancer security group"

    tags = {
        name = "alb_sg"
    }
}

# ingress rules
resource "aws_security_group" "sg_1" {
    vpc_id = module.network.vpc_id
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
    vpc_zone_identifier = [module.network.subnet_1_id, module.network.subnet_3_id]

    launch_template { # attach it to the ec2 instance
        id = aws_launch_template.ec2_application.id
        version = "$Latest"
    }

}

# make ec2 instance for management subnet
resource "aws_instance" "ec2_management" {
  ami = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  subnet_id = module.network.subnet_2_id
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
  subnets = [module.network.subnet_1_id, module.network.subnet_3_id] # use public/management subnet so internet can reach it

  tags = {
    Name = "app_lb"
  }
}

# target group for the ASG instances
resource "aws_lb_target_group" "app_tg" {
  name = "app-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = module.network.vpc_id

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

















