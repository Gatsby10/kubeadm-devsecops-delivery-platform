#!/bin/bash
##set up SSH key
mkdir -p /home/ubuntu/.ssh

#Add private key
cat <<EOF > /home/ubuntu/.ssh/id_rsa
${privatekey}
EOF

#Set permissions for the private key
chmod 400 /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

hostnamectl set-hostname bastionhost