sudo apt-get update
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible
##change to drive C of windows
cd /mnt/c
##change to drive D of windows
cd /mnt/d

export ANSIBLE_CONFIG=/mnt/d/Tech/AWSLearning/TerraformAnsibleWithAWS/code/ansible.cfg      