output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "app_sg_id" {
  value = aws_security_group.sg_1.id
}

output "management_sg_id" {
  value = aws_security_group.management_sg.id
}
