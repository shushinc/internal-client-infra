# Deploying EKS on AWS and Setting Up Cert-Manager, ALB Controller, and Karpenter

This guide provides step-by-step instructions to deploy an Amazon EKS cluster using a Terraform module and install **Cert-Manager**, **AWS Load Balancer (ALB) Controller**, and **Karpenter** using **Kustomize**.

---

## **Prerequisites**
1. **Tools installed:**
   - [Terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/)
   - [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
   - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. **AWS Credentials Configured:**
   - Ensure your AWS credentials are properly configured with sufficient permissions to create and manage EKS resources.

---

## **Step 1: Provision EKS Using Terraform**
1. **Set up the Terraform EKS module configuration:**

### Create the S3 Bucket for Terraform State:

Ensure you have an S3 bucket named shush-terraform-state to store your Terraform state files. This centralized storage maintains the state of your infrastructure. If you prefer a different bucket name, update the provider.tf file located within each service's folder (e.g., eks and ecr) to reflect the new bucket name.

### Configure the Backend in provider.tf:

In each service's provider.tf file, set up the backend configuration to point to your S3 bucket. This ensures Terraform uses the specified bucket for state management. Here's an example configuration:

Navigate to the `modules/eks` directory and edit the `terraform.tfvars` file to customize variables specific to your EKS deployment. This file allows you to define values for variables used in your Terraform configuration, tailoring the deployment to your requirements.

Do the same for the `module/ecr` folders.

Initialize and apply the Terraform configuration:

```bash
terraform init
terraform plan
terraform apply
```

Confirm the apply step and wait for the cluster to be created.

Configure kubectl to use the new cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name <my-eks-cluster>
```

## Step 2: Install Cert-Manager using Kustomize

Go to `core-apps > cert-manager > base` and execute:

```bash
kubectl kustomize | kubectl apply -f -
```

## Step 3: Install ALB Controller using Kustomize

Go to `core-apps > aws-lb-controller > overlays > development` and edit the file:

Add the name of the cluster in the file `add_cluster_name_to_args.yaml`
```
- op: replace
  path: /spec/template/spec/containers/0/args
  value:
    - "--cluster-name=eks-hudson"
    - "--ingress-class=alb"
```

then apply the changes to the kubernetes cluster:

```bash
kubectl kustomize | kubectl apply -f -
```

## Step 4: Install Karpenter using Kustomize

Go to `core-apps > karpenter > overlays > development` and execute:

```bash
kubectl kustomize | kubectl apply -f -
```

Validate the services are running using:

```bash
kubectl get po -n karpenter
kubectl get po -n kube-system
kubectl get po -n cert-manager
```

This guide covers a complete setup for EKS with essential controllers. Customize configurations as needed for your workloads.






