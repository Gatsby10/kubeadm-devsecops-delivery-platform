#!/bin/bash

# Installs HAProxy, Configures it as a TCP load balancer, 
# Forwards Kubernetes API traffic (port 6443) and Distributes
# requests across 3 master nodes

sudo apt update && sudo apt upgrade -y
sudo add-apt-repository ppa:vbernat/haproxy-2.9 -y
sudo apt update
sudo apt install haproxy -y

cat <<EOT > /etc/haproxy/haproxy.cfg
frontend k8s_api_front
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s_api_back

backend k8s_api_back
    balance roundrobin
    mode tcp
    option tcplog
    option tcp-check
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100

    server master1 ${master_ip_1}:6443 check
    server master2 ${master_ip_2}:6443 check
    server master3 ${master_ip_3}:6443 check

EOT

systemctl enable haproxy
systemctl restart haproxy