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
    command = "aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id};AWS_PROFILE=${var.profile} ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/install_jenkins_master.yml"
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
    command = "aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-ids ${self.id};AWS_PROFILE=${var.profile} ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name} master_ip=${aws_instance.jenkins_master.private_ip}' ansible_templates/install_jenkins_worker.yml"
  }
}

resource "null_resource" "jenkins-workers" {
  count = "${var.workers-count}"
  triggers = {
    master_private_ip = aws_instance.jenkins_master.private_ip
    worker_private_ip = "${element(aws_instance.jenkins-workers.*.private_ip, count.index)}"
    worker_public_ip = "${element(aws_instance.jenkins-workers.*.public_ip, count.index)}"
    instance_number   = "${count.index + 1}"
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "java -jar /home/ec2-user/jenkins-cli.jar -auth @/home/ec2-user/jenkins_auth -s http://${self.triggers.master_private_ip}:8080 delete-node ${self.triggers.worker_private_ip}"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      #private_key = file("/mnt/c/Users/Rishu/.ssh/jenkins_decripted.pem")
      agent = true
      host        = "34.209.179.141"
    }

  }

}

