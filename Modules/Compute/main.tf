####### Compute #######

# setting up security group for management ec2
resource "aws_security_group" "management_sg" {
    vpc_id = var.vpc_id
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
    vpc_id = var.vpc_id
    name = "alb_sg"
    description = "applicaton load balancer security group"

    tags = {
        name = "alb_sg"
    }
}

# ingress rules
resource "aws_security_group" "sg_1" {
    vpc_id = var.vpc_id
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
      name = var.iam_instance_profile_name
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
    vpc_zone_identifier = [var.subnet_1_id, var.subnet_3_id]

    launch_template { # attach it to the ec2 instance
        id = aws_launch_template.ec2_application.id
        version = "$Latest"
    }

}

# make ec2 instance for management subnet
resource "aws_instance" "ec2_management" {
  ami = "ami-052064a798f08f0d3"
  instance_type = "t2.micro"
  subnet_id = var.subnet_2_id
  vpc_security_group_ids = [aws_security_group.management_sg.id]
  tags = { Name = "ec2_management" }
}