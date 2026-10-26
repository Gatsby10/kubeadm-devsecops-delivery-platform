variable "name" {}
variable "vpc" {}
variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs for the bastion ASG"
}
variable "privatekey" {
  description = "SSH private key for accessing the bastion host"
}
