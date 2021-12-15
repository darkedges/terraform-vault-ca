provider "vault" {
}

resource "vault_mount" "pki_root" {
  path                      = "darkedges_root"
  type                      = "pki"
  description               = "This is an pki_root mount"
  default_lease_ttl_seconds = "315360000"
  max_lease_ttl_seconds     = "315360000"
}

resource "vault_mount" "pki_intermediate" {
  path                      = "darkedges_intermediate"
  type                      = "pki"
  description               = "This is an pki_intermediate mount"
  default_lease_ttl_seconds = "31536000"
  max_lease_ttl_seconds     = "31536000"
}

resource "vault_pki_secret_backend_config_urls" "darkedges_root_config_urls" {
  backend                 = vault_mount.pki_root.path
  crl_distribution_points = ["https://vault.darkedges.com/v1/${vault_mount.pki_root.path}/crl"]
  issuing_certificates    = ["https://vault.darkedges.com/v1/${vault_mount.pki_root.path}/ca"]
}

resource "vault_pki_secret_backend_config_urls" "darkedges_intermediate_config_urls" {
  backend                 = vault_mount.pki_intermediate.path
  crl_distribution_points = ["https://vault.darkedges.com/v1/${vault_mount.pki_intermediate.path}/crl"]
  issuing_certificates    = ["https://vault.darkedges.com/v1/${vault_mount.pki_intermediate.path}/ca"]
}

resource "vault_pki_secret_backend_root_cert" "root" {
  backend              = vault_mount.pki_root.path
  type                 = "internal"
  common_name          = "DarkEdges Root"
  ttl                  = "315360000"
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "IT"
  organization         = "DarkEdges"
  country              = "AU"
  locality             = "VIC"
}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  backend     = vault_mount.pki_intermediate.path
  type        = "internal"
  common_name = "DarkEdges Intermediate"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend              = vault_mount.pki_root.path
  csr                  = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  common_name          = "DarkEdges Intermediate"
  exclude_cn_from_sans = true
  ou                   = "DarkEdges"
  organization         = "IT"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_intermediate.path
  certificate = "${vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate}\n${vault_pki_secret_backend_root_sign_intermediate.intermediate.issuing_ca}"
}

resource "vault_pki_secret_backend_role" "admin" {
  backend          = vault_mount.pki_intermediate.path
  name             = "admin"
  allowed_domains  = ["darkedges.com"]
  allow_subdomains = true
  key_usage        = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  max_ttl          = "28296000"
}

resource "vault_pki_secret_backend_role" "darkedges" {
  backend               = vault_mount.pki_intermediate.path
  name                  = "darkedges"
  allow_any_name        = true
  require_cn            = false
  use_csr_common_name   = true
  enforce_hostnames     = false
  server_flag           = false
  client_flag           = true
  code_signing_flag     = false
  email_protection_flag = false
  key_bits              = 2048
  key_type              = "rsa"
  key_usage             = ["DigitalSignature"]
  max_ttl               = "28296000"
}

resource "vault_auth_backend" "approle" {
  type = "approle"

  tune {
    default_lease_ttl = "31536000s"
    max_lease_ttl     = "31536000s"
  }

}

resource "vault_policy" "darkedges" {
  name = "darkedges"

  policy = <<EOT
path "darkedges_intermediate/*" {
  capabilities = ["read","list","delete","update","create"]
}
EOT
}

resource "vault_approle_auth_backend_role" "darkedges" {
  backend        = vault_auth_backend.approle.path
  role_name      = "darkedges"
  token_policies = ["default", "darkedges"]
}
