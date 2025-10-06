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

# connect the compute module
module "compute" {
  source = "./modules/compute"
  vpc_id = module.network.vpc_id
  subnet_1_id = module.network.subnet_1_id
  subnet_2_id = module.network.subnet_2_id
  subnet_3_id = module.network.subnet_3_id
  my_ip_cidr = "192.168.137.1/32"
  image_id = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
}


############ Supporting Infrastructure ############

# create the application load balancer
resource "aws_lb" "app_lb" {
  name = "app-load-balancer"
  internal = false
  load_balancer_type = "application"
  security_groups = [module.compute.alb_sg_id]
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
  autoscaling_group_name = module.compute.asg_name
  lb_target_group_arn = aws_lb_target_group.app_tg.arn
}

############ IAM ############
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

















