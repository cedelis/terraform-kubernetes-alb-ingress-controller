locals {
  aws_alb_ingress_controller_docker_image = "docker.io/amazon/aws-alb-ingress-controller:v${var.aws_alb_ingress_controller_version}"
  aws_alb_ingress_class                   = "alb"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name        = "${var.aws_resource_name_prefix}${var.k8s_cluster_name}-alb-ingress-controller"
  description = "Permissions required by the Kubernetes AWS ALB Ingress controller to do it's job."
  path        = var.aws_iam_path_prefix

  tags = var.aws_tags

  force_detach_policies = true

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "alb_management" {
  statement {
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebACL",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "cognito-idp:DescribeUserPoolClient",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "tag:GetResources",
      "tag:TagResources",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "waf:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "this" {
  name        = "${var.aws_resource_name_prefix}${var.k8s_cluster_name}-alb-management"
  description = "Permissions that are required to manage the AWS Application Load Balancer."
  path        = var.aws_iam_path_prefix
  policy      = data.aws_iam_policy_document.alb_management.json
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "cluster_node_role" {
  policy_arn = aws_iam_policy.this.arn
  role       = var.k8s_cluster_node_role
}

resource "kubernetes_service_account" "this" {
  automount_service_account_token = true
  metadata {
    name      = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
    namespace = var.k8s_namespace

    labels = {
      "app.kubernetes.io/name"       = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_cluster_role" "this" {
  metadata {
    name = "${var.k8s_cluster_name}-aws-alb-ingress-controller"

    labels = {
      "app.kubernetes.io/name"       = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "configmaps",
      "endpoints",
      "events",
      "ingresses",
      "ingresses/status",
      "services",
    ]

    verbs = [
      "create",
      "get",
      "list",
      "update",
      "watch",
      "patch",
    ]
  }

  rule {
    api_groups = [
      "",
      "extensions",
    ]

    resources = [
      "nodes",
      "pods",
      "secrets",
      "services",
      "namespaces",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = "${var.k8s_cluster_name}-aws-alb-ingress-controller"

    labels = {
      "app.kubernetes.io/name"       = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.this.metadata[0].name
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_service_account.this.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "this" {
  depends_on = [kubernetes_cluster_role_binding.this]

  metadata {
    name      = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
    namespace = var.k8s_namespace

    labels = {
      "app.kubernetes.io/name"       = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
      "app.kubernetes.io/version"    = var.aws_alb_ingress_controller_version
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "field.cattle.io/description" = "AWS ALB Ingress Controller"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "${var.k8s_cluster_name}-aws-alb-ingress-controller"
          "app.kubernetes.io/version" = var.aws_alb_ingress_controller_version
        }

        annotations = {
          # Annotation to be used by KIAM
          "iam.amazonaws.com/role" = aws_iam_role.this.arn
        }
      }

      spec {
        dns_policy     = "ClusterFirst"
        restart_policy = "Always"

        container {
          name                     = "server"
          image                    = local.aws_alb_ingress_controller_docker_image
          image_pull_policy        = "Always"
          termination_message_path = "/dev/termination-log"

          args = [
            "--ingress-class=${local.aws_alb_ingress_class}",
            "--cluster-name=${var.k8s_cluster_name}",
            "--aws-vpc-id=${var.aws_vpc_id}",
            "--aws-region=${var.aws_region_name}",
            "--aws-max-retries=10",
          ]

          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name       = kubernetes_service_account.this.default_secret_name
            read_only  = true
          }

          port {
            name           = "health"
            container_port = 10254
            protocol       = "TCP"
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "health"
              scheme = "HTTP"
            }

            initial_delay_seconds = 30
            period_seconds        = 60
            timeout_seconds       = 3
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "health"
              scheme = "HTTP"
            }

            initial_delay_seconds = 60
            period_seconds        = 60
          }
        }

        volume {
          name = kubernetes_service_account.this.default_secret_name

          secret {
            secret_name = kubernetes_service_account.this.default_secret_name
          }
        }

        service_account_name             = kubernetes_service_account.this.metadata[0].name
        termination_grace_period_seconds = 60
      }
    }
  }
}
