# vektor-ml-enclave — VEKTOR-PRD.md §14.2 "Python Enclave Security".
#
# The two vektor-ml services (cv-train-svc, llm-cloud-svc) are treated as
# untrusted third-party dependencies from the TS application layer's
# perspective. This module is the structural enforcement of that: a
# default-deny namespace that only opens the one hole the architecture
# actually needs — gRPC ingress from coa-svc — plus metrics scraping.
#
# What this module deliberately does NOT do, because §14.2 forbids it:
#   - no egress rule to PostgreSQL/Redis/MinIO — storage access is proxied
#     through TypeScript services, never called directly from the enclave
#   - no shared volumes with any vektor-platform workload (§9.3, §9.5)
# Image scanning (Trivy) and repo write-access restriction are enforced
# outside this repo — vektor-ml's own CI (§9.8) and GitHub team permissions
# (§9.9), respectively.

resource "kubernetes_namespace_v1" "vektor_ml_enclave" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/enclave"                  = "python"
      "vektor.io/trust-boundary"           = "untrusted"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

resource "kubernetes_resource_quota_v1" "enclave_quota" {
  metadata {
    name      = "vektor-ml-enclave-quota"
    namespace = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"            = var.resource_quota.cpu
      "requests.memory"         = var.resource_quota.memory
      "limits.cpu"              = var.resource_quota.cpu
      "limits.memory"           = var.resource_quota.memory
      "requests.nvidia.com/gpu" = var.resource_quota.gpu
      "limits.nvidia.com/gpu"   = var.resource_quota.gpu
    }
  }
}

# Default-deny: no pod in the enclave can send or receive anything unless a
# later policy explicitly opens it. This is the actual isolation boundary —
# everything below is a narrow, named exception to it.
resource "kubernetes_network_policy_v1" "default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

# The one permitted runtime call in the whole architecture: coa-svc ->
# llm-cloud-svc over gRPC (vektor-proto/proto/llm.proto). No other TS
# service, and nothing outside the cluster, may reach the enclave.
#
# SEC-002 audit note: cv-train-svc (this enclave's other named service, per
# the module header) deliberately gets no matching ingress-allow rule — it's
# a CLI-driven batch training job (vektor-ml/cv-train-svc/src/cv_train_svc/
# {cli,train,export}.py), not a server with any inbound listener. The
# default-deny-all policy above is already the correct, complete posture for
# it; adding an ingress rule for a service nothing ever calls would be an
# unused hole, not a fix.
resource "kubernetes_network_policy_v1" "allow_grpc_from_coa_svc" {
  metadata {
    name      = "allow-grpc-from-coa-svc"
    namespace = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = {
        "app" = "llm-cloud-svc"
      }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.platform_namespace
          }
        }
        pod_selector {
          match_labels = {
            "app" = "coa-svc"
          }
        }
      }
      ports {
        port     = var.grpc_port
        protocol = "TCP"
      }
    }
  }
}

# Prometheus (observability namespace) is allowed to scrape both enclave
# services' /metrics endpoint. Scrape traffic only — nothing else in or out.
resource "kubernetes_network_policy_v1" "allow_metrics_scrape" {
  metadata {
    name      = "allow-metrics-scrape"
    namespace = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.observability_namespace
          }
        }
      }
      ports {
        port     = var.metrics_port
        protocol = "TCP"
      }
    }
  }
}

# DNS resolution is the only egress hole — every enclave pod needs it to
# resolve the K8s service DNS name for its own sidecar/health endpoints, but
# gets nothing else outbound (§14.2: no direct storage access).
#
# SEC-002 audit fix (2026-08-26): this used to select `namespace_selector {}`
# with no match_labels — a bare empty block still means "any namespace," so
# the egress hole was effectively "port 53 to anywhere in the cluster," not
# just to CoreDNS. Narrowed to var.dns_namespace (defaults to "kube-system",
# where CoreDNS lives on k3s and most standard clusters); a cluster with
# DNS elsewhere overrides the variable rather than reopening this to
# everything again.
resource "kubernetes_network_policy_v1" "allow_dns_egress" {
  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace_v1.vektor_ml_enclave.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.dns_namespace
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}
