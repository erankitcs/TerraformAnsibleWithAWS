# Load balancer of application type for jenkins master.
resource "aws_lb" "application-lb" {
  provider           = aws.region-master
  name               = "jenkins-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sg.id]
  subnets            = [aws_subnet.subnet_master1.id, aws_subnet.subnet_master2.id]
  tags = {
    Name = "Jenkins-LB"
  }
}

# Load balancer target group 
resource "aws_lb_target_group" "app-lb-tg" {
  provider    = aws.region-master
  name        = "app-lb-tg"
  port        = var.webserver-port
  target_type = "instance"
  vpc_id      = aws_vpc.vpc_master.id
  protocol    = "HTTP"
  health_check {
    enabled  = true
    interval = 10
    path     = "/"
    port     = var.webserver-port
    protocol = "HTTP"
    matcher  = "200-299"
  }
  tags = {
    Name = "jenkins-target-group"
  }
}

# Load balancer listner and forward traffic to target group.
resource "aws_lb_listener" "jenkins-listener-http" {
  provider          = aws.region-master
  load_balancer_arn = aws_lb.application-lb.arn
  port              = var.webserver-port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-lb-tg.id
  }
}
# Attach target group with instance.
resource "aws_lb_target_group_attachment" "jenkins-master-attach" {
  provider         = aws.region-master
  target_group_arn = aws_lb_target_group.app-lb-tg.arn
  target_id        = aws_instance.jenkins_master.id
  port             = var.webserver-port
}