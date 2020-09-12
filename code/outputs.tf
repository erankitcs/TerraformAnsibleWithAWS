output "jenkins-master-node-public-ip" {
  value = aws_instance.jenkins_master.public_ip
}

output "jenkins-worker-nodes-public-ip" {
  value = {
    for instance in aws_instance.jenkins-workers :
    instance.id => instance.public_ip
  }
}

# LB DNS name
output "LB-DNS-NAME" {
  value = aws_lb.application-lb.dns_name
}