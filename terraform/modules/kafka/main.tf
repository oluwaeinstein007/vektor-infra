# INFRA-004 — Deploy Kafka cluster (3 brokers + Schema Registry).
# kafkajs (vektor-backend) and the Schema Registry are the only two things
# every downstream service (ingest-svc, fusion-svc, alert-svc, ...) depends
# on for the event backbone described in §9.7.

resource "kubernetes_namespace_v1" "streaming" {
  metadata {
    name = var.namespace
    labels = {
      "vektor.io/tier" = "streaming"
    }
  }
}

resource "helm_release" "kafka" {
  name       = "vektor-kafka"
  namespace  = kubernetes_namespace_v1.streaming.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kafka"
  version    = var.chart_version

  # KRaft mode — no ZooKeeper, one less stateful dependency to run HA (R-009).
  set {
    name  = "kraft.enabled"
    value = "true"
  }
  set {
    name  = "controller.replicaCount"
    value = var.broker_count
  }
  set {
    name  = "controller.persistence.size"
    value = var.storage_size
  }
  set {
    name  = "controller.persistence.storageClass"
    value = var.storage_class
  }
  # ISR=2 for a 3-broker cluster: tolerates one broker down with zero data
  # loss on acks=all producers — matches R-009's mitigation exactly.
  set {
    name  = "controller.extraConfig"
    value = "default.replication.factor=3\nmin.insync.replicas=2\noffsets.topic.replication.factor=3"
  }
}

# Confluent Schema Registry, pointed at the Kafka bootstrap service the
# Bitnami chart creates. Avro/JSON-Schema compatibility checks here are what
# R-006 ("Kafka topic schema drift breaks consumers") relies on in practice —
# vektor-proto is the source of truth, this is the runtime enforcement point.
resource "kubernetes_deployment_v1" "schema_registry" {
  metadata {
    name      = "schema-registry"
    namespace = kubernetes_namespace_v1.streaming.metadata[0].name
    labels    = { app = "schema-registry" }
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "schema-registry" }
    }
    template {
      metadata {
        labels = { app = "schema-registry" }
      }
      spec {
        container {
          name  = "schema-registry"
          image = var.schema_registry_image
          port {
            container_port = 8081
          }
          env {
            name  = "SCHEMA_REGISTRY_HOST_NAME"
            value = "schema-registry"
          }
          env {
            name  = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
            value = "PLAINTEXT://vektor-kafka.${var.namespace}.svc.cluster.local:9092"
          }
          env {
            name  = "SCHEMA_REGISTRY_LISTENERS"
            value = "http://0.0.0.0:8081"
          }
        }
      }
    }
  }
  depends_on = [helm_release.kafka]
}

resource "kubernetes_service_v1" "schema_registry" {
  metadata {
    name      = "schema-registry"
    namespace = kubernetes_namespace_v1.streaming.metadata[0].name
  }
  spec {
    selector = { app = "schema-registry" }
    port {
      port        = 8081
      target_port = 8081
    }
  }
}
