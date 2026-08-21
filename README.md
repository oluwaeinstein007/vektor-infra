# vektor-infra

Terraform (cloud + on-prem), Kubernetes-layer config, ArgoCD `Application`/`ApplicationSet` defs, Istio policy, and Vault policy for [VEKTOR](../vektor-docs/VEKTOR-PRD.md). See PRD §9.2, §9.8–§9.9.

## What this repo does — and doesn't — provision

Terraform here manages **resources inside an existing Kubernetes cluster** (namespaces, Helm releases, network policies, Vault auth/policy) via the `kubernetes`, `helm`, and `vault` providers. It does not provision the cluster's underlying machines: §11.1–§11.3 describe owned/colo bare-metal hardware in every tier (Cloud Core, On-Prem DC, Tactical Edge), not a named hyperscaler, so there's no cloud API for Terraform to call for that layer. Cluster bootstrap is a separate step:

- **Dev**: `scripts/bootstrap-k3s-dev.sh` — single-node k3s, ~2 minutes.
- **Prod**: RKE2 across the §11.3 rack, a change-controlled runbook (DevOps + Security Lead approval, §9.9) — not automated here on purpose.

## Layout

```
terraform/
  modules/
    vektor-ml-enclave/   Namespace + NetworkPolicy + ResourceQuota for the Python enclave (§14.2)
    kafka/                3-broker Kafka (KRaft) + Schema Registry (INFRA-004)
    data-stores/           MinIO + Qdrant + Redis Cluster (INFRA-006)
    gateway/                Kong (DB-less) + Keycloak (INFRA-007)
    observability/           kube-prometheus-stack + Loki + Jaeger (INFRA-009)
    vault/                    HA Vault + Kubernetes auth backend + policy wiring (INFRA-010)
    istio/                     mTLS STRICT across TS services only (SEC-001)
  environments/
    dev/     One k3s node, everything downsized, local state
    prod/    §11.2/§11.3-sized, Kubernetes-Secret state backend
k8s/argocd/applications/   GitOps entry points for vektor-platform + vektor-ml workloads
vault/policies/             HCL policies, one per repo's trust boundary (§14.2)
scripts/                     Cluster bootstrap (dev only — see above)
```

## Why `vektor-ml-enclave` is its own module and everything else isn't

It's the one module every other module's NetworkPolicy or Istio config has to be aware doesn't get the same treatment (no mesh injection, no storage egress) — see the inline comments in `terraform/modules/vektor-ml-enclave/main.tf` and `terraform/modules/istio/variables.tf`. Splitting it out makes that asymmetry a file boundary, not a comment someone has to remember while editing a shared module.

## Local development

```bash
./scripts/bootstrap-k3s-dev.sh
cd terraform/environments/dev
terraform init
terraform apply
```

`terraform validate` and `terraform fmt -check -recursive` both pass against every module and environment as of this writing — `terraform plan`/`apply` need a real cluster, which isn't part of this repo's CI (see PRD §9.8: `vektor-infra`'s CI posts `terraform plan` as a PR comment and gates `apply` on DevOps + Security Lead approval, it doesn't run apply itself).
