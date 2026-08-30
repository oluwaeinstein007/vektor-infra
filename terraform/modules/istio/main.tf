# SEC-001 — Istio mTLS enforcement across all TS services.

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.chart_version
}

resource "helm_release" "istiod" {
  name       = "istiod"
  namespace  = kubernetes_namespace_v1.istio_system.metadata[0].name
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.chart_version

  depends_on = [helm_release.istio_base]
}

resource "kubernetes_labels" "mesh_injection" {
  for_each    = toset(var.mesh_namespaces)
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = each.value
  }
  labels = {
    "istio-injection" = "enabled"
  }
}

# Mesh-wide STRICT mTLS — plaintext traffic between any two mesh sidecars is
# rejected, not merely upgraded opportunistically. This is what actually
# closes the "Unauthorized data access" threat-model row (§14.1) at the
# network layer, on top of RBAC.
#
# NOTE: kubernetes_manifest requires the PeerAuthentication CRD to already
# exist in the cluster at plan time (istiod must be installed first). In
# practice this means `terraform apply -target=helm_release.istiod` once,
# then a normal `terraform apply` — a documented Terraform+CRD limitation,
# not something specific to this repo.
resource "kubernetes_manifest" "mesh_peer_auth" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "PeerAuthentication"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
    }
    spec = {
      mtls = {
        mode = "STRICT"
      }
    }
  }
  depends_on = [helm_release.istiod]
}

# SEC-001, completed: this module previously stopped at STRICT mTLS (L4
# transport identity) and deliberately did NOT add AuthorizationPolicy
# resources (L7 — "is this specific caller allowed to call this specific
# service"), because no ServiceAccount-per-service naming convention existed
# anywhere in this repo yet — see git history on this file for the original
# audit note and the exact call graph it derived from reading
# vektor-backend's source. That blocker is now resolved: every
# vektor-backend service's Helm chart (services/<name>/deploy/helm) fixes
# its ServiceAccount name to the plain service name (e.g. "coa-svc", not a
# release-name-derived one) specifically so AuthorizationPolicy rules here
# have a real, stable identity to match against — see ADR-0012 and each
# chart's _helpers.tpl.
#
# Every AuthorizationPolicy below was written against the real, verified
# call graph (not guessed): coa-svc -> audit-svc (POST /api/v1/audit),
# coa-svc -> fusion-svc (GET /api/v1/no-strike-zones), and Kong
# (vektor-gateway namespace) -> every public-facing vektor-backend service.
# fusion-svc -> alert-svc is NOT an HTTP call (BullMQ over Redis), so it has
# no Istio-mesh AuthorizationPolicy analog. ingest-svc has no inbound
# listener at all (a Kafka producer/adapter process, same reasoning
# vektor-ml-enclave's module already applies to cv-train-svc) — it
# deliberately gets no AuthorizationPolicy, matching its Helm chart having
# no Service resource either.
#
# Istio's actual semantics matter here: an AuthorizationPolicy with
# action=ALLOW selecting a workload makes that workload deny-by-default for
# everything NOT matching one of its rules (across all ALLOW policies that
# select it) - there is no separate "apply default-deny first" step. This
# is why each service below gets exactly one policy naming every source
# that's allowed to reach it, not a bare deny-all plus something else.
locals {
  # Every public-facing vektor-backend service that needs Kong ingress
  # allowed - i.e. everything except ingest-svc (no listener).
  backend_public_services = [
    "fusion-svc", "coa-svc", "alert-svc", "audit-svc", "geospatial-svc",
    "logistics-svc", "reporting-svc", "map-tile-server", "cv-inference-svc",
    "edge-sync-svc",
  ]
}

resource "kubernetes_manifest" "allow_kong_ingress" {
  for_each = toset(local.backend_public_services)

  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "allow-kong-ingress"
      namespace = var.backend_namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = each.value
        }
      }
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                namespaces = [var.gateway_namespace]
              }
            },
          ]
        },
      ]
    }
  }
  depends_on = [kubernetes_manifest.mesh_peer_auth]
}

# coa-svc -> audit-svc, scoped to exactly the one call it makes
# (services/coa-svc/src/audit/client.ts's createAuditClient().write()) -
# not a bare "allow coa-svc" rule, since that would open every audit-svc
# route (including the SuperAdmin-only GET /api/v1/audit) to a service that
# only ever needs to POST.
resource "kubernetes_manifest" "allow_coa_svc_to_audit_svc" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "allow-coa-svc-audit-write"
      namespace = var.backend_namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "audit-svc"
        }
      }
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                principals = ["cluster.local/ns/${var.backend_namespace}/sa/coa-svc"]
              }
            },
          ]
          to = [
            {
              operation = {
                methods = ["POST"]
                paths   = ["/api/v1/audit"]
              }
            },
          ]
        },
      ]
    }
  }
  depends_on = [kubernetes_manifest.allow_kong_ingress]
}

# coa-svc -> fusion-svc, scoped to exactly the one call it makes
# (services/coa-svc/src/context/fetchNoStrikeZones.ts).
resource "kubernetes_manifest" "allow_coa_svc_to_fusion_svc" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "allow-coa-svc-no-strike-zones-read"
      namespace = var.backend_namespace
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "fusion-svc"
        }
      }
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                principals = ["cluster.local/ns/${var.backend_namespace}/sa/coa-svc"]
              }
            },
          ]
          to = [
            {
              operation = {
                methods = ["GET"]
                paths   = ["/api/v1/no-strike-zones"]
              }
            },
          ]
        },
      ]
    }
  }
  depends_on = [kubernetes_manifest.allow_kong_ingress]
}
