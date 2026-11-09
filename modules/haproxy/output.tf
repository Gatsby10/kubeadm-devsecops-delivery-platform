output "haproxy_ips" {
  value = aws_instance.haproxy.*.private_ip
}