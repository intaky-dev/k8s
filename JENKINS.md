# Jenkins CI/CD en K3s

Guía completa para desplegar y usar Jenkins en tu cluster k3s con soporte completo para CI/CD, agentes Kubernetes, y Docker-in-Docker.

## Características

✅ **Jenkins Controller LTS** con configuración optimizada
✅ **Agentes Kubernetes Dinámicos** - escalan según demanda
✅ **Docker-in-Docker** - construye imágenes dentro de pipelines
✅ **Plugins Pre-instalados**:
  - Git, GitHub, GitLab, Bitbucket
  - Docker Pipeline
  - Kubernetes Plugin
  - Blue Ocean UI
  - Prometheus Metrics
  - Pipeline plugins completos

✅ **20Gi Almacenamiento Persistente**
✅ **Configuración como Código (JCasC)**
✅ **Alta Disponibilidad** lista para producción

## Requisitos

### Cluster K3s
Debes tener k3s ya instalado:
```bash
cd ~/Desktop/Dev/k8s
./quick-start.sh
```

### Recursos Mínimos
- **Controller**: 2 CPU, 4Gi RAM
- **Agentes**: 1 CPU, 1Gi RAM por agente
- **Almacenamiento**: 20Gi
- **Total recomendado**: 4 CPU, 8Gi RAM, 30Gi disco

## Instalación Rápida

### Opción 1: Script Interactivo (Recomendado)

```bash
cd ~/Desktop/Dev/k8s

# Configurar kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Desplegar Jenkins
./deploy-jenkins.sh
```

El script:
1. ✅ Verifica que k3s esté corriendo
2. ✅ Instala Helm si no está disponible
3. ✅ Despliega Jenkins con Helm
4. ✅ Muestra credenciales de admin
5. ✅ Ofrece iniciar port-forward automáticamente

### Opción 2: Terraform

```bash
cd ~/Desktop/Dev/k8s

# Habilitar Jenkins en terraform.tfvars
cat >> terraform.tfvars <<EOF
jenkins_enabled = true
jenkins_storage_size = "20Gi"
jenkins_cpu_limit = "2000m"
jenkins_memory_limit = "4Gi"
EOF

# Aplicar cambios
terraform apply
```

### Opción 3: Makefile

```bash
cd ~/Desktop/Dev/k8s

# Desplegar
make jenkins-deploy

# Ver estado
make jenkins-status

# Obtener password
make jenkins-password
```

## Acceso a Jenkins

### 1. Obtener Credenciales

```bash
# Username
echo "admin"

# Password
kubectl get secret -n jenkins jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

O usando Makefile:
```bash
make jenkins-password
```

### 2. Port Forward

```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

Luego abre en tu navegador: **http://localhost:8080**

### 3. Acceso desde Fuera del Cluster (Opcional)

Si necesitas acceder desde otra máquina en la red:

```bash
# Opción A: NodePort
kubectl patch svc jenkins -n jenkins -p '{"spec": {"type": "NodePort"}}'

# Ver el puerto asignado
kubectl get svc jenkins -n jenkins

# Opción B: Ingress (requiere configuración adicional)
# Ver documentación de ingress en README.md
```

## Configuración

### Variables de Terraform

| Variable | Descripción | Default |
|----------|-------------|---------|
| `jenkins_enabled` | Habilitar Jenkins | `false` |
| `jenkins_version` | Versión del Helm chart | `""` (latest) |
| `jenkins_storage_size` | Tamaño del PV | `"20Gi"` |
| `jenkins_cpu_limit` | Límite de CPU | `"2000m"` |
| `jenkins_memory_limit` | Límite de RAM | `"4Gi"` |
| `jenkins_enable_docker` | Habilitar Docker-in-Docker | `true` |

### Personalizar Configuración

Edita `templates/jenkins-values.yaml` para:
- Cambiar plugins instalados
- Ajustar recursos de agentes
- Configurar autenticación
- Agregar scripts de inicialización
- Modificar configuración JCasC

## Uso

### 1. Crear tu Primer Pipeline

1. Accede a Jenkins (http://localhost:8080)
2. Login con credenciales de admin
3. Clic en "New Item"
4. Nombre: "test-pipeline"
5. Tipo: "Pipeline"
6. En "Pipeline" → "Script", pega:

```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Kubernetes agent!'
                sh 'uname -a'
                sh 'kubectl version --client'
            }
        }
    }
}
```

7. Clic en "Save" y "Build Now"

### 2. Pipeline con Docker

```groovy
pipeline {
    agent {
        kubernetes {
            label 'docker'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
  - name: docker
    image: docker:dind
    tty: true
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-storage
      mountPath: /var/lib/docker
  volumes:
  - name: docker-storage
    emptyDir: {}
"""
        }
    }
    stages {
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    sh '''
                    echo "FROM alpine:latest" > Dockerfile
                    echo "RUN echo 'Hello World'" >> Dockerfile
                    docker build -t test:latest .
                    docker images
                    '''
                }
            }
        }
    }
}
```

### 3. Pipeline con Git

```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/user/repo.git'
            }
        }
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
    }
}
```

### 4. Integración con Langflow

Pipeline para ejecutar workflows de Langflow:

```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
        }
    }
    stages {
        stage('Trigger Langflow Workflow') {
            steps {
                script {
                    def response = httpRequest(
                        url: 'http://langflow-ide.langflow.svc.cluster.local:7860/api/v1/run',
                        httpMode: 'POST',
                        contentType: 'APPLICATION_JSON',
                        requestBody: '''
                        {
                            "flow_id": "your-flow-id",
                            "inputs": {
                                "input": "data from jenkins"
                            }
                        }
                        '''
                    )
                    echo "Response: ${response.content}"
                }
            }
        }
    }
}
```

## Plugins Instalados

### SCM & Git
- `git` - Git plugin
- `github` - GitHub integration
- `github-branch-source` - GitHub Branch Source
- `gitlab-plugin` - GitLab integration
- `bitbucket` - Bitbucket integration

### Docker
- `docker-workflow` - Docker Pipeline
- `docker-plugin` - Docker plugin

### Pipeline
- `workflow-aggregator` - Pipeline suite
- `pipeline-stage-view` - Stage view
- `pipeline-graph-view` - Graph view
- `pipeline-build-step` - Build step

### Kubernetes
- `kubernetes` - Kubernetes plugin (agentes dinámicos)

### UI
- `blueocean` - Blue Ocean UI moderna
- `dark-theme` - Tema oscuro

### Seguridad
- `role-strategy` - Role-based access control
- `matrix-auth` - Matrix-based security

### Utilidades
- `prometheus` - Métricas Prometheus
- `ansicolor` - Salida con colores
- `timestamper` - Timestamps en logs

## Comandos Útiles

### Ver Logs

```bash
# Logs del controller
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller -f

# Logs de un agente específico
kubectl logs -n jenkins <agent-pod-name> -c jnlp
```

### Gestión de Pods

```bash
# Ver todos los recursos
kubectl get all -n jenkins

# Ver pods (controller + agentes activos)
kubectl get pods -n jenkins

# Ver servicios
kubectl get svc -n jenkins

# Ver almacenamiento
kubectl get pvc -n jenkins
```

### Restart Jenkins

```bash
# Método 1: Rollout
kubectl rollout restart deployment jenkins -n jenkins

# Método 2: Eliminar pod (se recrea automáticamente)
kubectl delete pod -n jenkins -l app.kubernetes.io/component=jenkins-controller
```

### Acceder al Container

```bash
# Shell en Jenkins controller
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- bash

# Ver archivos
kubectl exec -n jenkins -it svc/jenkins -c jenkins -- ls -la /var/jenkins_home
```

### Backup

```bash
# Backup de Jenkins home
kubectl cp jenkins/<pod-name>:/var/jenkins_home ./jenkins-backup

# Restaurar backup
kubectl cp ./jenkins-backup jenkins/<pod-name>:/var/jenkins_home
```

## Configuración Avanzada

### Agregar más Agentes

Edita `templates/jenkins-values.yaml` y agrega nuevas templates:

```yaml
- name: "python-agent"
  label: "python"
  containers:
    - name: "python"
      image: "python:3.11"
      command: "cat"
      ttyEnabled: true
```

Úsalo en pipelines:
```groovy
agent {
    kubernetes {
        label 'python'
    }
}
```

### Configurar Webhooks

1. En GitHub/GitLab:
   - Settings → Webhooks
   - URL: `http://<jenkins-url>/github-webhook/`
   - Events: Push, Pull Request

2. En Jenkins:
   - Job → Configure
   - Build Triggers → GitHub hook trigger

### Credenciales

```bash
# Agregar credential via CLI
kubectl exec -n jenkins -it svc/jenkins -- \
  jenkins-cli create-credentials-by-xml system::system::jenkins _ <<EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>github-token</id>
  <username>your-username</username>
  <password>your-token</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
```

O usa la UI de Jenkins: Manage Jenkins → Credentials

### Monitoring con Prometheus

Jenkins expone métricas en:
```
http://jenkins:8080/prometheus/
```

Para configurar Prometheus:
```yaml
scrape_configs:
  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins.jenkins.svc.cluster.local:8080']
    metrics_path: '/prometheus/'
```

## Troubleshooting

### Jenkins no inicia

```bash
# Ver logs
kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller

# Ver eventos
kubectl get events -n jenkins --sort-by='.lastTimestamp'

# Verificar recursos
kubectl describe pod -n jenkins -l app.kubernetes.io/component=jenkins-controller
```

### Agentes no se conectan

```bash
# Verificar servicio de agente
kubectl get svc jenkins-agent -n jenkins

# Ver logs del agente
kubectl logs -n jenkins <agent-pod> -c jnlp

# Verificar RBAC
kubectl auth can-i create pods --namespace jenkins --as system:serviceaccount:jenkins:jenkins
```

### Problemas de almacenamiento

```bash
# Ver PVC
kubectl get pvc -n jenkins

# Ver PV
kubectl get pv | grep jenkins

# Verificar storage class
kubectl get storageclass
```

### Reset de password

```bash
# Obtener nuevo password
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# O regenerar secret
kubectl delete secret -n jenkins jenkins
kubectl rollout restart deployment jenkins -n jenkins
```

## Desinstalación

### Con Script

```bash
# Desinstalar Jenkins pero mantener k3s
helm uninstall jenkins -n jenkins
kubectl delete namespace jenkins
```

### Con Terraform

```bash
# Deshabilitar en terraform.tfvars
jenkins_enabled = false

# Aplicar
terraform apply
```

### Completa

```bash
# Eliminar todo incluyendo PVCs
helm uninstall jenkins -n jenkins
kubectl delete namespace jenkins --grace-period=0 --force
```

## Mejores Prácticas

### 1. Seguridad
- ✅ Cambiar password de admin inmediatamente
- ✅ Habilitar autenticación de 2 factores
- ✅ Usar credentials para secrets
- ✅ No exponer Jenkins directamente a internet
- ✅ Mantener plugins actualizados

### 2. Performance
- ✅ Usar agentes Kubernetes (no el controller)
- ✅ Configurar límites de recursos apropiados
- ✅ Limpiar builds antiguos automáticamente
- ✅ Usar Docker cache para builds

### 3. Pipelines
- ✅ Usar Jenkinsfile en repositorios
- ✅ Implementar stages claros
- ✅ Agregar notificaciones (email, Slack)
- ✅ Usar parallel stages cuando sea posible

### 4. Backup
- ✅ Backup regular de `/var/jenkins_home`
- ✅ Versionar Jenkinsfiles en Git
- ✅ Documentar configuración importante
- ✅ Exportar configuración JCasC

## Recursos

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [JCasC Documentation](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Helm Chart](https://github.com/jenkinsci/helm-charts)

## Siguientes Pasos

1. ✅ Crear tu primer pipeline
2. ✅ Configurar webhooks con GitHub/GitLab
3. ✅ Integrar con Langflow
4. ✅ Configurar notificaciones
5. ✅ Setup de backups automáticos
6. ✅ Explorar Blue Ocean UI

## Soporte

Si encuentras problemas:
1. Revisa los logs: `kubectl logs -n jenkins -l app.kubernetes.io/component=jenkins-controller`
2. Verifica el estado: `kubectl get all -n jenkins`
3. Consulta la [documentación oficial](https://www.jenkins.io/doc/)
