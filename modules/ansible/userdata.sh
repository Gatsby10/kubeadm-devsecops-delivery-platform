#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
  software-properties-common \
  python3 \
  python3-pip \
  git \
  unzip \
  curl \
  wget

# Install Ansible
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

##set up SSH key
mkdir -p /home/ubuntu/.ssh

#Add private key
cat <<EOF > /home/ubuntu/.ssh/id_rsa
${privatekey}
EOF

#Set permissions for the private key
chmod 400 /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

hostnamectl set-hostname ansible-control-node

# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ln -svf /usr/local/bin/aws /usr/bin/aws

sudo bash -c 'echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config'

# pull playbooks from s3
aws s3 cp s3://"${bucket_name}"/playbooks /etc/ansible/playbooks --recursive

# Update Ansible inventory file
echo "[master1]" > /etc/ansible/hosts
echo "${master1_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "[master2-3]" >> /etc/ansible/hosts
echo "${master2_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "${master3_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "[workers]" >> /etc/ansible/hosts
echo "${worker1_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "${worker2_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "${worker3_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "[haproxy-1]" >> /etc/ansible/hosts
echo "${haproxy1_ip} ansible_user=ubuntu" >> /etc/ansible/hosts
echo "[haproxy-2]" >> /etc/ansible/hosts
echo "${haproxy2_ip} ansible_user=ubuntu" >> /etc/ansible/hosts

# create ansible variables file
echo "haproxy1_ip: ${haproxy1_ip}" > /etc/ansible/haproxy.yml
echo "haproxy2_ip: ${haproxy2_ip}" >> /etc/ansible/haproxy.yml

sudo chown -R ubuntu:ubuntu /etc/ansible

# Run Ansible playbook to install Kubernetes components
sudo su -c "ansible-playbook /etc/ansible/playbooks/installation.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/keepalived.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/main-master.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/join-master.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/join-nodes.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/kubectl.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/stage.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/prod.yml" ubuntu
sudo su -c "ansible-playbook /etc/ansible/playbooks/monitoring.yml" ubuntu
