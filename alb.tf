resource "aws_lb" "dotnet_alb" {

  name               = "dotnet-bluegreen-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    data.aws_security_group.ec2_sg.id
  ]

  subnets = [
    data.aws_subnet.subnet1.id,
    data.aws_subnet.subnet2.id
  ]
}

resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.dotnet_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {

    type             = "forward"
    target_group_arn = data.aws_lb_target_group.blue.arn

  }
}
