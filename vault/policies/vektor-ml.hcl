# Vault policy for the vektor-ml Kubernetes auth role (vektor-ml-enclave
# namespace only). Deliberately narrow — §14.2 treats these two services as
# untrusted from the TS layer's perspective, and that distrust extends to
# secrets: no database credentials, no MinIO credentials (storage access is
# proxied through TypeScript services, never called directly from the
# enclave), just what llm-cloud-svc/cv-train-svc need to start up.

path "secret/data/vektor-ml/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/vektor-ml/*" {
  capabilities = ["list"]
}

# llm-cloud-svc terminates mTLS itself (llm_cloud_svc/server.py) since
# vektor-ml-enclave sits outside the Istio mesh — this is the leaf-cert
# issuance permission that backs it. Only the vektor-ml-server role, never
# the general-purpose PKI root.
path "pki/issue/vektor-ml-server" {
  capabilities = ["create", "update"]
}

