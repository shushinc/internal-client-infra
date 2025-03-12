# AWS Load Balancer Controller

This controller will handle **all** `Ingress` resources in our Sift EKS cluster(s). It creates and manages AWS ALBs
(Application Load Balancer).

Since ALBs can route traffic based on the hostname (the http Host header), in general we only ever need a single ALB
per-cluster (see the
[`group.name`](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/#group.name)
annotiation).

The controller will use "Pod Identity" to assume an AWS IAM Role so that it can create and manage the AWS Resources. The
role is created by `Terragrunt` in the [terragunt.hcl](../../development/global/iam/pod-identity/aws-lb-controller/terragrunt.hcl) file, and is associated with the
`ServiceAccount` that's created by the controller manifest.

The only customization that needs to be done, is to set the cluster name in the container command line, which is done
with a kustomization patch: see `./overlays/development/add_cluster_name_to_args.yaml`.

## Updates to the controller

To update the controller, you need to update the `base/install.yaml` manifest from the latest release manifest. The
project releases ready-to-use `.yaml` files on their "GitHub Releases" page.

0. Read the project [release notes](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases).
1. Download the yaml file from the release assets (for ex. `v2_7_2_full.yaml`).
2. Copy it to `./base/install.yaml`.
3. Open a Pull-Request and specify major changes from the release notes (if any), and specify what you upgrade from and
   to.

## Additional resources

- [AWS Load Balancer controller docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [AWS Load Balancer controller project](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
- [Pod Identities](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
