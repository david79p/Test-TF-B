# EKS Getting Started Guide Configuration

This is the full configuration from https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html

See that guide for additional information.

NOTE: This full configuration utilizes the [Terraform http provider](https://www.terraform.io/docs/providers/http/index.html) to call out to icanhazip.com to determine your local workstation external IP for easily configuring EC2 Security Group access to the Kubernetes master servers. Feel free to replace this as necessary.

# terraform-aws-eks

A terraform module to create a managed Kubernetes cluster on AWS EKS. Available
through the [Terraform registry](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws).
Inspired by and adapted from [this doc](https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html)
and its [source code](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started).
Read the [AWS docs on EKS to get connected to the k8s dashboard](https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html).

## Prerequesits
* Install kubectl
https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
* Install aws-iam-authenticator
https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html
* Install terraform
https://www.terraform.io/intro/getting-started/install.html

## Assumptions

* You want to create an EKS cluster and an autoscaling group of workers for the cluster.
* You want these resources to exist within security groups that allow communication and coordination. These can be user provided or created within the module.
* You've created a Virtual Private Cloud (VPC) and subnets where you intend to put the EKS resources.
* Both [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl) (>=1.10) and [`aws-iam-authenticator`](https://github.com/kubernetes-sigs/aws-iam-authenticator#4-set-up-kubectl-to-use-authentication-tokens-provided-by-aws-iam-authenticator-for-kubernetes) are installed and on your shell's PATH.


## Usage example

This module should be declared as a module in your main manifest folder.
How to declare from the state manifest:

```hcl
module "aws_eks_cluster" {
  source = "../../modules/tf-module-eks-cluster"

  environment     = "dev"
  cluster_name    = "${var.cluster_name}"
  ssh_key_name    = "${var.eks_key_name}"
  ssh_access_pool = "${data.terraform_remote_state.mgmt_account.mgmt_vpc_cidr_block}"
  vpc_id          = "${module.dev_vpc.vpc_id}"
  worker_subnets  = "${module.dev_vpc.private_subnets_ids}"
  public_subnets  = "${module.dev_vpc.public_subnets_ids}"
}
```

# Description of the variables: #

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| environment | Environment short name, eg: dev, stage, prod | string | - | yes |
| cluster_name | Full name of the cluster | string | - | yes |
| instance_type | Instance type used for Kubernetes workers | string | `m5.large` | no |
| ssh_key_name | Existent SSH key name used for Kubernetes workers | string | - | yes |
| root_volume_size | Size for root volume of the Kubernetes workers | string | `50` | yes |
| min_nodes | Minimum number of Kubernets workers | string | `2` | no |
| max_nodes | Maximum number of Kubernets workers | string | `10` | no |
| vpc_id | Id of the VPC where the Kubernetes cluster will be deployed | string | - | yes |
| worker_subnets | Private subnets for your worker nodes | list | - | yes |
| public_subnets | Public subnets for Kubernetes to create internet-facing load balancers within | list | - | no |
| ssh_access_pool | IP range allowed to SSH on Kubernetes workers | string | - | yes |
| bastion_role | Role ARN for an EC2 instance that will have full access to EKS cluster | string | - | yes |
| jenkins_role | Role ARN for an Jenkins instance that will have access to EKS cluster | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| config_map_aws_auth | Config Map used to allow worker nodes to join the cluster via AWS IAM role authentication |
| kubeconfig | Configuration for kubectl |

## Deploy the Kubernetes Web UI (Dashboard)

Step 1: Deploy the Dashboard
1. Deploy the Kubernetes dashboard to your cluster:
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml`

2. Deploy heapster to enable container cluster monitoring and performance analysis on your cluster:
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml`

3. Deploy the influxdb backend for heapster to your cluster:
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml`

4. Create the heapster cluster role binding for the dashboard:
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml`

Step 2: Create an eks-admin Service Account and Cluster Role Binding
The example service account created with this procedure has full cluster-admin (superuser) privileges on the cluster. For more information, see Using RBAC Authorization in the Kubernetes documentation.
https://kubernetes.io/docs/admin/authorization/rbac/

1. Create a file called eks-admin-service-account.yaml with the text below:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-admin
  namespace: kube-system
```

2. Apply the service account to your cluster:
`kubectl apply -f eks-admin-service-account.yaml`

3. Create a file called eks-admin-cluster-role-binding.yaml with the text below:
```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: eks-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: eks-admin
  namespace: kube-system
```

4. Apply the cluster role binding to your cluster:
`kubectl apply -f eks-admin-cluster-role-binding.yaml`


Step 3: Connect to the Dashboard

Now that the Kubernetes dashboard is deployed to your cluster, and you have an administrator service account that you can use to view and control your cluster, you can connect to the dashboard with that service account.
To connect to the Kubernetes dashboard
1. Retrieve an authentication token for the eks-admin service account. Copy the <authentication_token> value from the output. You use this token to connect to the dashboard.
`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')`

2. Start the kubectl proxy.
`kubectl proxy`

3. Open the following link with a web browser to access the dashboard endpoint: http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

4. Choose Token, paste the <authentication_token> output from the previous command into the Token field, and choose SIGN IN.

All info taken from here: https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html
