# Deploying Kubernetes Applications with Kustomize

## Deployment Steps

Ensure Prerequisites

- Kubernetes Cluster: Access to a running Kubernetes cluster.
- kubectl: Installed and configured
- Kustomize: Installed.

## Navigate to the Directory

Go to the directory where your Kustomize configuration files are located:
```bash
cd apps/hss/base
```

Deploy the application to your Kubernetes cluster using the following command:
```bash
kubectl apply -k .
```
