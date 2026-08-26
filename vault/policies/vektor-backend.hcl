# Vault policy for the vektor-backend Kubernetes auth role.
# Any pod whose ServiceAccount lives in the vektor-backend namespace gets
# this policy — read-only access to its own secret tree. Nothing here can
# read vektor-ml's tree (see vektor-ml.hcl) — the two are deliberately
# disjoint, mirroring the repo/namespace split in §9.

path "secret/data/vektor-backend/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/vektor-backend/*" {
  capabilities = ["list"]
}

# Dynamic, short-lived PostgreSQL credentials (rotated by Vault's database
# secrets engine) rather than a static password anyone could exfiltrate.
path "database/creds/vektor-backend-readwrite" {
  capabilities = ["read"]
}

# coa-svc's client cert for the llm-cloud-svc mTLS handshake — see
# llm_cloud_svc/server.py's _load_server_credentials docstring (vektor-ml
# repo) for why this exists outside the Istio mesh. Scoped to the
# coa-svc-client role only; no other vektor-backend service gets a cert
# the enclave's server would accept.
path "pki/issue/vektor-backend-coa-svc-client" {
  capabilities = ["create", "update"]
}
