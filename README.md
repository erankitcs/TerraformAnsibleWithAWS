# Using Terraform and Ansible with AWS
This projected aimed to practice Terraform and Ansible in AWS. We would be creating Jenkins servers with necessary networking. 

## Steps to install

1. Run terraform_install.sh to install terraform
2. Run install-ansible.sh to install Ansible
3. Update S3 bucket and AWS  Profile in backend.tf
4. Update profile and DNS in variabled.tf
5. Update public_key location for both master_keypair and worker_keypair inside instances.tf
6. Run Terraform commands
- cd codo/
- terraform init
- terroform plan
- terraform apply

### To work with Ubuntu on WSL (Windows 10 with Windows Subsystem for Linux)

- change to windows drive using cd /mnt/c or cd /mnt/d
- Export cfg file  location eg.
    export ANSIBLE_CONFIG=/mnt/d/Tech/AWSLearning/TerraformAnsibleWithAWS/code/ansible.cfg

## Architecture

## Demo 
![Screenshot](AWSTerrraformAndAnsible.gif)