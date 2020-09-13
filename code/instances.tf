# Linux AMI for Master Jenkins
data "aws_ssm_parameter" "ami_master_jenkins" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Linux AMI for Worker Jenkins
data "aws_ssm_parameter" "ami_worker_jenkins" {
  provider = aws.region-worker
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Create Key Pair for Master Jenkins Ec2
resource "aws_key_pair" "master_keypair" {
  provider   = aws.region-master
  key_name   = "jenkins-master"
  public_key = file("/mnt/c/Users/Rishu/.ssh/jenkins.pub")
}

# Create Key Pair for Worker Jenkins Ec2
resource "aws_key_pair" "worker_keypair" {
  provider   = aws.region-worker
  key_name   = "jenkins-worker"
  public_key = file("/mnt/c/Users/Rishu/.ssh/jenkins.pub")
}

# Create EC2 Instance in Master VPC
resource "aws_instance" "jenkins_master" {
  provider                    = aws.region-master
  ami                         = data.aws_ssm_parameter.ami_master_jenkins.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master_keypair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.subnet_master1.id
  provisioner "local-exec" {
    command = "aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id};AWS_PROFILE=${var.profile} ansible-playbook -vvvvv --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/install_jenkins.yaml"
  }
  tags = {
    Name = "jenkins_master_tf"
  }
  depends_on = [aws_main_route_table_association.set-mastervpc-rt]
}

#Create EC2 in worker VPCs
resource "aws_instance" "jenkins-workers" {
  provider                    = aws.region-worker
  count                       = var.workers-count
  ami                         = data.aws_ssm_parameter.ami_worker_jenkins.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.worker_keypair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg-worker.id]
  subnet_id                   = aws_subnet.subnet_worker1.id
  tags = {
    Name = join("_", ["jenkins_worker_tf", count.index + 1])
  }
  depends_on = [aws_main_route_table_association.set-workervpc-rt, aws_instance.jenkins_master]
  provisioner "local-exec" {
    command = "aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-ids ${self.id};AWS_PROFILE=${var.profile} ansible-playbook -vvvvv --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name} master_ip=${aws_instance.jenkins_master.private_ip}' ansible_templates/install_worker.yaml"
  }
}