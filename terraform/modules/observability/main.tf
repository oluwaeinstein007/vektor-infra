# INFRA-009 — Observability stack (Prometheus, Grafana, Pino->Loki, OTel/Jaeger).
# §10.5: metrics via Prometheus+Grafana, logs via Pino->Loki->Grafana, traces
# via OpenTelemetry JS SDK -> Jaeger. All three ship as one namespace so
# every other module's NetworkPolicy has a single, stable namespace name
# (var.namespace, referenced as vektor-observability elsewhere) to allow
# scrape/export traffic from.

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/tier" = "observability"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "vektor-observability"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "67.9.0"

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }
  # Auto-discover ServiceMonitors from every namespace — each vektor-backend
  # service ships its own ServiceMonitor next to its Deployment rather than
  # this repo hand-listing every scrape target.
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}

resource "helm_release" "loki" {
  name       = "vektor-loki"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.21.0"

  set {
    name  = "loki.commonConfig.replication_factor"
    value = "1"
  }
  set {
    name  = "singleBinary.replicas"
    value = "1"
  }
  set {
    name  = "singleBinary.persistence.size"
    value = var.loki_storage_size
  }
}

resource "helm_release" "jaeger" {
  name       = "vektor-jaeger"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  version    = "3.4.1"

  set {
    name  = "provisionDataStore.cassandra"
    value = "false"
  }
  set {
    name  = "storage.type"
    value = "elasticsearch"
  }
  set {
    name  = "storage.elasticsearch.host"
    value = "elasticsearch.vektor-data.svc.cluster.local"
  }
}
