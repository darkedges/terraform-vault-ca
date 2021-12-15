# HashiCorp Vault Certifciate Authority via Terraform

## Deploy Configuration

```dos
set VAULT_ADDR=https://vault.darkedges.com
set TF_VAULT_TOKEN=xxxxxxxx
terraform init
terraform plan
terraform apply --auto-approve
```

## Get AppRole token

```dos
vault login
```

```dos
vault read auth/approle/role/darkedges/role-id
Key        Value
---        -----
role_id    zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
```

```dos
vault write -force auth/approle/role/darkedges/secret-id
Key                   Value
---                   -----
secret_id             yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
secret_id_accessor    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
secret_id_ttl         0s
```

```dos
curl https://vault.darkedges.com/v1/auth/approle/login --request POST --data "{\"role_id\":\"zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz\",\"secret_id:\", \"yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy\"}'
{
    "request_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "lease_id": "",
    "renewable": false,
    "lease_duration": 0,
    "data": null,
    "wrap_info": null,
    "warnings": null,
    "auth": {
        "client_token": "xxxxxxxxxxxxxxxxxxxxxxxxxx",
        "accessor": "xxxxxxxxxxxxxxxxxxxxxxxx",
        "policies": [
            "darkedges",
            "default"
        ],
        "token_policies": [
            "darkedges",
            "default"
        ],
        "metadata": {
            "role_name": "darkedges"
        },
        "lease_duration": 31536000,
        "renewable": true,
        "entity_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "token_type": "service",
        "orphan": true
    }
}
```
