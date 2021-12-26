# terraform-darkedges-ca

## Deploy Configuration

**Note:** Using `powershell`

## Deploy

```powershell
$nodeport = kubectl get svc darkedges-vault-ui -o=jsonpath='{.spec.ports[?(@.port==8200)].nodePort}'
$env:VAULT_ADDR="http://localhost:$nodeport"
$env:VAULT_TOKEN ="root"
terraform init
terraform plan
terraform apply --auto-approve
kubectl apply -f k8s
```
