provider "vault" {
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

resource "vault_mount" "pki_root" {
  path                      = "darkedges_idam_root"
  type                      = "pki"
  description               = "This is an pki_root mount"
  default_lease_ttl_seconds = "315360000"
  max_lease_ttl_seconds     = "315360000"
}

resource "vault_mount" "pki_intermediate" {
  path                      = "darkedges_idam_intermediate"
  type                      = "pki"
  description               = "This is an pki_intermediate mount"
  default_lease_ttl_seconds = "31536000"
  max_lease_ttl_seconds     = "31536000"
}

resource "vault_pki_secret_backend_config_urls" "darkedges_idam_root_config_urls" {
  backend                 = vault_mount.pki_root.path
  crl_distribution_points = ["https://vault.darkedges.com/v1/${vault_mount.pki_root.path}/crl"]
  issuing_certificates    = ["https://vault.darkedges.com/v1/${vault_mount.pki_root.path}/ca"]
}

resource "vault_pki_secret_backend_config_urls" "darkedges_idam_intermediate_config_urls" {
  backend                 = vault_mount.pki_intermediate.path
  crl_distribution_points = ["https://vault.darkedges.com/v1/${vault_mount.pki_intermediate.path}/crl"]
  issuing_certificates    = ["https://vault.darkedges.com/v1/${vault_mount.pki_intermediate.path}/ca"]
}

resource "vault_pki_secret_backend_root_cert" "root" {
  depends_on           = [vault_mount.pki_root]
  backend              = vault_mount.pki_root.path
  type                 = "internal"
  common_name          = "Westpac New Zealand CIAM Root"
  ttl                  = "315360000"
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "idam"
  organization         = "darkedges"
  country              = "NZ"
  locality             = "Auckland"
}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  depends_on  = [vault_mount.pki_intermediate]
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = "darkedges_idam Intermediate"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  depends_on           = [vault_pki_secret_backend_intermediate_cert_request.intermediate]
  backend              = vault_mount.pki_root.path
  csr                  = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  common_name          = "Westpac New Zealand CIAM Intermediate"
  exclude_cn_from_sans = true
  ou                   = "ciam"
  organization         = "darkedges"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_intermediate.path
  certificate = "${vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate}\n${vault_pki_secret_backend_root_sign_intermediate.intermediate.issuing_ca}"
}

resource "vault_pki_secret_backend_role" "admin" {
  backend          = vault_mount.pki_intermediate.path
  name             = "admin"
  allowed_domains  = [".darkedges.com"]
  allow_subdomains = true
  max_ttl          = "28296000"
  key_usage        = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
}

resource "vault_pki_secret_backend_role" "darkedges_idam" {
  backend             = vault_mount.pki_intermediate.path
  name                = "darkedges_idam"
  allowed_domains     = [".darkedges.com", "cluster.local"]
  allow_subdomains    = true
  allow_glob_domains  = true
  use_csr_common_name = true
  require_cn          = false
  key_usage           = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
}

data "kubernetes_service_account" "certmanager" {
  metadata {
    name = "certmanager"
  }
}

data "kubernetes_secret" "certmanager" {
  metadata {
    name = data.kubernetes_service_account.certmanager.default_secret_name
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "example" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://10.96.0.1:443"
  kubernetes_ca_cert     = data.kubernetes_secret.certmanager.data["ca.crt"]
  token_reviewer_jwt     = data.kubernetes_secret.certmanager.data["token"]
  issuer                 = "api"
  disable_iss_validation = "true"
}

resource "vault_policy" "certmanager-policy" {
  name = "certmanager-policy"

  policy = <<EOT
path "darkedges_idam_intermediate/*" {
  capabilities = ["read","list","delete","update","create"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "certmanager" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "certmanager"
  bound_service_account_names      = ["certmanager", "darkedges-vault-certmanager"]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = ["${vault_policy.certmanager-policy.name}"]
  audience                         = null
}