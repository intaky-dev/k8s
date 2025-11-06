# K3s Kubernetes Cluster for Ubuntu

Este módulo de Terraform instala y configura un cluster de Kubernetes usando **k3s** en tu servidor Ubuntu. K3s es una distribución certificada de Kubernetes, ligera y fácil de mantener, perfecta para deployments en servidores locales.

## ¿Qué es K3s?

K3s es una distribución de Kubernetes:
- **Ligera**: ~100MB binario
- **Rápida**: Instalación en segundos
- **Certificada**: 100% Kubernetes compatible
- **Production-ready**: Usado por miles de empresas
- **Incluye todo**: Ingress, storage, métricas

## Aplicaciones Disponibles

Este cluster k3s incluye soporte para:
- **Langflow**: Plataforma de desarrollo de workflows con IA
- **Jenkins CI/CD**: Sistema completo de integración y deployment continuo

Ver [JENKINS.md](./JENKINS.md) para documentación completa de Jenkins.

## Requisitos

### Sistema
- Ubuntu 20.04+ (o cualquier distribución Linux compatible)
- Mínimo 2GB RAM
- Mínimo 2 CPU cores
- 20GB espacio en disco

### Software
- Terraform >= 1.5.0
- curl
- Acceso sudo en el servidor

## Instalación Rápida

### 1. Preparar Configuración

```bash
cd ~/Desktop/Dev/k8s

# Copiar archivo de ejemplo
cp terraform.tfvars.example terraform.tfvars

# Editar según necesites (opcional)
vim terraform.tfvars
```

### 2. Instalar K3s

```bash
# Inicializar Terraform
terraform init

# Revisar plan
terraform plan

# Aplicar (instalar k3s)
terraform apply
```

El proceso toma aproximadamente 2-3 minutos e incluye:
- ✅ Descarga e instalación de k3s
- ✅ Configuración de kubectl
- ✅ Configuración de storage local
- ✅ Instalación de metrics-server
- ✅ Verificación del cluster

### 3. Verificar Instalación

```bash
# Configurar kubectl
export KUBECONFIG=$(pwd)/kubeconfig

# Verificar nodos
kubectl get nodes

# Verificar pods del sistema
kubectl get pods -A

# Verificar storage class
kubectl get storageclass
```

Deberías ver algo como:
```
NAME     STATUS   ROLES                  AGE   VERSION
ubuntu   Ready    control-plane,master   1m    v1.28.5+k3s1
```

## Configuración Detallada

### Variables Disponibles

| Variable | Descripción | Default | Ejemplo |
|----------|-------------|---------|---------|
| `k3s_version` | Versión de k3s a instalar | `""` (latest) | `"v1.28.5+k3s1"` |
| `k3s_install_options` | Opciones de instalación | `"server --disable traefik"` | Ver abajo |
| `server_ip` | IP del servidor | `"127.0.0.1"` | `"192.168.1.100"` |
| `server_port` | Puerto API server | `6443` | `6443` |
| `setup_local_storage` | Configurar storage local | `true` | `true/false` |
| `install_metrics_server` | Instalar metrics-server | `true` | `true/false` |

### Opciones de K3s

```hcl
# Configuración básica (recomendada)
k3s_install_options = "server --disable traefik"

# Configuración avanzada
k3s_install_options = "server --disable traefik --write-kubeconfig-mode 644 --cluster-cidr 10.42.0.0/16"

# Sin desactivar nada (usar todos los componentes de k3s)
k3s_install_options = "server"
```

Opciones útiles:
- `--disable traefik`: Desactiva Traefik (usaremos nginx-ingress de langflow)
- `--disable servicelb`: Desactiva service load balancer (si usarás MetalLB)
- `--write-kubeconfig-mode 644`: Hacer kubeconfig legible por todos
- `--cluster-cidr`: CIDR personalizado para pods
- `--service-cidr`: CIDR personalizado para servicios
- `--node-label`: Agregar labels al nodo
- `--node-taint`: Agregar taints al nodo

### Acceso Remoto

Para acceder al cluster desde otra máquina:

1. Cambiar `server_ip` a la IP real del servidor:
```hcl
server_ip = "192.168.1.100"  # IP real del servidor
```

2. Asegurar que el firewall permita el puerto 6443:
```bash
sudo ufw allow 6443/tcp
```

3. Copiar el archivo `kubeconfig` a tu máquina remota:
```bash
# En la máquina remota
scp usuario@servidor:~/Desktop/Dev/k8s/kubeconfig ~/.kube/config-k3s
export KUBECONFIG=~/.kube/config-k3s
kubectl get nodes
```

## Despliegue de Aplicaciones

Una vez que el cluster k3s está funcionando, puedes desplegar aplicaciones.

### Opción 1: Langflow Infrastructure

Desplegar Langflow (plataforma de workflows con IA):

```bash
# 1. Obtener ruta del kubeconfig
export K3S_KUBECONFIG=$(terraform output -raw kubeconfig_path)

# 2. Ir al directorio de langflow-infra
cd ../langflow-infra

# 3. Inicializar si no lo has hecho
terraform init

# 4. Crear terraform.tfvars personalizado
cat > terraform.tfvars <<EOF
# Kubernetes Configuration
kubeconfig_path = "$K3S_KUBECONFIG"
namespace       = "langflow"
environment     = "prod"

# Configuración reducida para servidor local
postgres_replicas    = 1
rabbitmq_replicas    = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 5

# Desactivar observability para ahorrar recursos (opcional)
enable_observability = false

# Configuración de ingress (ajustar según tu dominio)
ingress_enabled    = true
ide_ingress_host   = "langflow.local"
tls_enabled        = false  # Activar después si necesitas HTTPS
EOF

# 5. Desplegar Langflow
terraform plan
terraform apply

# 6. Acceder a Langflow
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
# Abrir en navegador: http://localhost:7860
```

### Opción 2: Jenkins CI/CD

Desplegar Jenkins para pipelines de CI/CD:

```bash
# Método rápido con script interactivo
./deploy-jenkins.sh

# O usando Makefile
make jenkins-deploy

# O con Terraform
cat >> terraform.tfvars <<EOF
jenkins_enabled = true
EOF
terraform apply

# Acceder a Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Abrir en navegador: http://localhost:8080

# Obtener password de admin
make jenkins-password
# O directamente:
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

**Características de Jenkins:**
- ✅ Agentes Kubernetes dinámicos
- ✅ Docker-in-Docker para builds
- ✅ Plugins pre-instalados (Git, Docker, Pipeline, Blue Ocean)
- ✅ Integración con GitHub/GitLab/Bitbucket
- ✅ 20Gi almacenamiento persistente
- ✅ Métricas Prometheus
- ✅ Configuration as Code (JCasC)

**Documentación completa**: Ver [JENKINS.md](./JENKINS.md)

## Operaciones Comunes

### Ver Información del Cluster

```bash
# Información general
kubectl cluster-info

# Recursos del sistema
kubectl top nodes
kubectl top pods -A

# Logs de k3s
sudo journalctl -u k3s -f
```

### Backup del Cluster

```bash
# Backup de etcd (base de datos de k3s)
sudo k3s etcd-snapshot save --name backup-$(date +%Y%m%d-%H%M%S)

# Los backups se guardan en: /var/lib/rancher/k3s/server/db/snapshots/
```

### Restaurar Backup

```bash
# Detener k3s
sudo systemctl stop k3s

# Restaurar snapshot
sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/backup-20240101-120000

# Iniciar k3s
sudo systemctl start k3s
```

### Actualizar K3s

```bash
# Opción 1: Cambiar version en terraform.tfvars
vim terraform.tfvars
# k3s_version = "v1.29.0+k3s1"
terraform apply

# Opción 2: Actualización manual
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.29.0+k3s1" sh -
```

### Agregar Nodos Worker (opcional)

```bash
# En el servidor master, obtener el token
sudo cat /var/lib/rancher/k3s/server/node-token

# En el worker node
curl -sfL https://get.k3s.io | K3S_URL=https://IP_MASTER:6443 K3S_TOKEN=TOKEN sh -
```

## Troubleshooting

### K3s no inicia

```bash
# Ver logs
sudo journalctl -u k3s -n 100 --no-pager

# Verificar estado
sudo systemctl status k3s

# Reiniciar
sudo systemctl restart k3s
```

### kubectl no funciona

```bash
# Verificar kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
cat $KUBECONFIG

# Verificar que k3s está corriendo
sudo systemctl status k3s

# Re-generar kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ./kubeconfig
sudo chown $USER:$USER ./kubeconfig
```

### Pods en estado Pending

```bash
# Verificar recursos
kubectl describe node

# Verificar eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Verificar storage
kubectl get pv
kubectl get pvc -A
```

### Problemas de Storage

```bash
# Verificar storage class
kubectl get storageclass

# Ver persistent volumes
kubectl get pv

# Hacer local-path default si no lo es
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Recursos y Límites

### Configuración Mínima (Dev/Test)
- 2GB RAM
- 2 CPU
- 20GB disco

### Configuración Recomendada (Producción)
- 8GB RAM
- 4 CPU
- 100GB disco SSD

### Con Langflow Completo
- 16GB RAM
- 8 CPU
- 200GB disco SSD

## Desinstalación

### Destruir solo Langflow

```bash
cd ~/Desktop/Dev/langflow-infra
terraform destroy
```

### Destruir K3s Completo

```bash
cd ~/Desktop/Dev/k8s
terraform destroy
```

Esto ejecutará `/usr/local/bin/k3s-uninstall.sh` que:
- Detiene todos los servicios
- Elimina todos los containers
- Limpia iptables rules
- Elimina archivos de configuración
- Preserva logs en `/var/log/` (eliminar manualmente si es necesario)

## Estructura de Archivos

```
k8s/
├── main.tf                     # Configuración principal
├── variables.tf                # Variables de entrada
├── outputs.tf                  # Outputs del módulo
├── terraform.tfvars.example    # Ejemplo de configuración
├── terraform.tfvars            # Tu configuración (git-ignored)
├── templates/
│   └── kubeconfig.tpl         # Template de kubeconfig
├── kubeconfig                  # Kubeconfig generado
└── README.md                   # Este archivo
```

## Siguientes Pasos

1. ✅ Instalar k3s con este módulo
2. ✅ Verificar que el cluster funciona
3. ⏭️ Desplegar Langflow usando ../langflow-infra
4. ⏭️ Configurar ingress/DNS si es necesario
5. ⏭️ Configurar backups automáticos

## Referencias

- [K3s Documentation](https://docs.k3s.io/)
- [K3s GitHub](https://github.com/k3s-io/k3s)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Langflow Infrastructure](../langflow-infra/)

## Soporte

Si encuentras problemas:
1. Revisa los logs: `sudo journalctl -u k3s -f`
2. Verifica el estado: `kubectl get pods -A`
3. Consulta la [documentación de k3s](https://docs.k3s.io/)

## Licencia

MIT
