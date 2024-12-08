#######################################################################################################################
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#######################################################################################################################

resource "aws_iam_role" "eks-cluster" {
  name = "${var.environment}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

resource "aws_security_group" "eks-cluster" {
  name        = "${var.environment}-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    CreatedBy = "Terraform"
    Name      = "${var.environment}-eks-cluster"
  }
}

resource "aws_security_group_rule" "eks-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-cluster.id}"
  source_security_group_id = "${aws_security_group.eks-cluster-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

############################################################################
# Attach additional IAM policy for using Load Balancers & Cluster Autoscaler
############################################################################

resource "aws_iam_policy" "additional_eks_policy" {
  name        = "${var.environment}AdditionalEKSClusterPolicy"
  path        = "/"
  description = "Additional access rights for ${var.environment} EKS cluster"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "arn:aws:iam::*:role/aws-service-role/*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "ec2:DescribeAccountAttributes"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AdditionalEKSClusterPolicy" {
  policy_arn = "${aws_iam_policy.additional_eks_policy.arn}"
  role       = "${aws_iam_role.eks-cluster.name}"
}

#############################################################
# Allow inbound traffic from Management VPC to the Kubernetes
#############################################################
resource "aws_security_group_rule" "eks-cluster-ingress-vpn-https" {
  cidr_blocks       = ["${var.ssh_access_pool}"]
  description       = "Allow VPN to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.eks-cluster.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "${var.cluster_name}"
  role_arn = "${aws_iam_role.eks-cluster.arn}"
  version  = "${var.k8s_version}"

  vpc_config {
    security_group_ids      = ["${aws_security_group.eks-cluster.id}"]
    subnet_ids              = ["${var.worker_subnets}", "${var.public_subnets}"]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy",
  ]
}

########################################################################
# Allow worker nodes to join the cluster via AWS IAM role authentication
########################################################################

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks-cluster-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${var.jenkins_role}
      username: jenkins:{{EC2PrivateDNSName}}
      groups:
        - system:masters
    - rolearn: ${var.bastion_role}
      username: bastion:{{EC2PrivateDNSName}}
      groups:
        - system:masters

CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks-cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
KUBECONFIG
}

resource "local_file" "kubeconfig" {
  content  = "${local.kubeconfig}"
  filename = "/tmp/${var.cluster_name}-kubeconfig"
}

resource "local_file" "config-map" {
  content  = "${local.config_map_aws_auth}"
  filename = "/tmp/${var.cluster_name}-config_map_aws_auth.yaml"

  provisioner "local-exec" {
    command = "kubectl apply -f /tmp/${var.cluster_name}-config_map_aws_auth.yaml --kubeconfig=/tmp/${var.cluster_name}-kubeconfig"
  }

  depends_on = ["local_file.kubeconfig"]
}

data "template_file" "cluster-autoscaler" {
  template = "${file("${path.module}/files/cluster-autoscaler.yaml")}"

  vars {
    cluster_name = "${var.cluster_name}"
    region       = "${var.region}"
  }
}

resource "local_file" "cluster-autoscaling" {
  content  = "${data.template_file.cluster-autoscaler.rendered}"
  filename = "/tmp/${var.cluster_name}-autoscaler.yaml"

  provisioner "local-exec" {
    command = "kubectl apply -f /tmp/${var.cluster_name}-autoscaler.yaml --kubeconfig=/tmp/${var.cluster_name}-kubeconfig"
  }
}

resource "null_resource" "horizontal-pod-autoscaling" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/horizontal-pod-autoscaler.yaml --kubeconfig=/tmp/${var.cluster_name}-kubeconfig"
  }
}
