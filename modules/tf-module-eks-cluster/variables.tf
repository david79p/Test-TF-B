#######################################################################################################################
# Variables Configuration
#######################################################################################################################

variable "environment" {
  description = "Environment short name, eg: dev, stage, prod"
  type        = "string"
}

variable "cluster_name" {
  description = "Full name of the cluster"
  type        = "string"
}

variable "region" {
  description = "AWS Region to be used"
  type        = "string"
}

variable "instance_type" {
  description = "Instance type used for Kubernetes workers"
  default     = "m5.large"
  type        = "string"
}

variable "ssh_key_name" {
  description = "Existent SSH key name used for Kubernetes workers"
  default     = ""
  type        = "string"
}

variable "root_volume_size" {
  description = "Size for root volume of the Kubernetes workers"
  default     = "50"
  type        = "string"
}

variable "min_nodes" {
  description = "Minimum number of Kubernets workers"
  default     = "2"
  type        = "string"
}

variable "max_nodes" {
  description = "Maximum number of Kubernets workers"
  default     = "10"
  type        = "string"
}

variable "vpc_id" {
  description = "Id of the VPC where the Kubernetes cluster will be deployed"
  type        = "string"
}

variable "worker_subnets" {
  description = "Private subnets for your worker nodes"
  type        = "list"
}

variable "public_subnets" {
  description = "Public subnets for Kubernetes to create internet-facing load balancers within"
  type        = "list"
  default     = []
}

variable "ssh_access_pool" {
  description = "IP range allowed to SSH on Kubernetes workers"
  default     = ""
}

variable "bastion_role" {
  description = "Role ARN for an EC2 instance that will have full access to EKS cluster"
  default     = ""
}

variable "jenkins_role" {
  description = "Role ARN for an Jenkins instance that will have access to EKS cluster"
  default     = ""
}

variable "k8s_version" {
  description = "Worker node AMI Version of K8s to use"
  default     = "1.10"
}

variable "optional_tags" {
  type        = "list"
  description = "A list of additional tags in explicit format to add to Autoscaling Group."
  default     = []
}
