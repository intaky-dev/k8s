# Quick Start Guide

## Instalación en 3 comandos

```bash
# 1. Verificar prerrequisitos
./check-prerequisites.sh

# 2. Instalar k3s
./quick-start.sh

# 3. Configurar kubectl
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

¡Listo! Tu cluster de Kubernetes está funcionando.

## Desplegar Aplicaciones

### Opción A: Jenkins CI/CD

```bash
# Desplegar Jenkins (método interactivo)
./deploy-jenkins.sh

# O con Makefile
make jenkins-deploy

# Acceder a Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Abrir: http://localhost:8080

# Obtener password
make jenkins-password
```

Ver [JENKINS.md](./JENKINS.md) para documentación completa.

### Opción B: Langflow

```bash
# 1. Ir al directorio de langflow-infra
cd ../langflow-infra

# 2. Configurar
cat > terraform.tfvars <<EOF
kubeconfig_path = "$(cd ../k8s && pwd)/kubeconfig"
namespace       = "langflow"
environment     = "prod"

# Configuración optimizada para servidor local
postgres_replicas    = 1
rabbitmq_replicas    = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 5

# Ahorra recursos desactivando observability
enable_observability = false

# Ingress local
ingress_enabled  = true
ide_ingress_host = "langflow.local"
tls_enabled      = false
EOF

# 3. Desplegar
terraform init
terraform apply

# 4. Acceder
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
# Abrir: http://localhost:7860
```

## Usar Makefile (alternativa)

```bash
# Instalar k3s
make setup

# Configurar kubectl
eval $(make kubeconfig)

# Ver estado
make status

# Jenkins
make jenkins-deploy    # Desplegar Jenkins
make jenkins-status    # Ver estado de Jenkins
make jenkins-password  # Obtener password de admin

# Backup
make backup

# Destruir
make destroy
```

## Comandos Útiles

```bash
# Ver todos los pods
kubectl get pods -A

# Ver logs de un pod
kubectl logs -n langflow <pod-name> -f

# Ver recursos
kubectl top nodes
kubectl top pods -A

# Abrir shell en un pod
kubectl exec -it -n langflow <pod-name> -- bash

# Port-forward de servicios
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
```

## Troubleshooting Rápido

### k3s no inicia
```bash
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

### kubectl no conecta
```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl cluster-info
```

### Pods en Pending
```bash
kubectl describe pod -n langflow <pod-name>
kubectl get events -n langflow --sort-by='.lastTimestamp'
```

## Desinstalar

```bash
# Solo destruir langflow
cd ../langflow-infra
terraform destroy

# Destruir todo (k3s incluido)
cd ../k8s
terraform destroy
```

## Ayuda

- Ver README.md completo: `cat README.md`
- Documentación k3s: https://docs.k3s.io/
- Documentación Langflow: https://docs.langflow.org/
