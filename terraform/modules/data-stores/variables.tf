variable "namespace" {
  description = "Namespace for MinIO + Qdrant + Redis — INFRA-006."
  type        = string
  default     = "vektor-data"
}

variable "minio_storage_size" {
  description = "Hot-tier MinIO capacity. §11.2 specs 100 TB hot imagery in prod; dev overrides this much smaller."
  type        = string
  default     = "2Ti"
}

variable "minio_storage_class" {
  type    = string
  default = "nvme-ssd"
}

variable "qdrant_replica_count" {
  type    = number
  default = 3
}

variable "qdrant_storage_size" {
  type    = string
  default = "200Gi"
}

variable "redis_shard_count" {
  description = "Redis Cluster shards — backs hot entity cache, alert pub/sub, BullMQ (§10.4)."
  type        = number
  default     = 6
}

variable "redis_replicas_per_shard" {
  type    = number
  default = 1
}
