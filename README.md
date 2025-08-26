# 🏰 Workshop — “Castillos y Escudos: el despliegue apurado del desarrollador”

## 🎯 Objetivo
Simular un despliegue inseguro y mostrar cómo los **4 escudos** (Trivy, OPA/Conftest, Kyverno y Fluentd) protegen al clúster en diferentes etapas.

---

## 🔧 Instalación de herramientas

### Windows (PowerShell)
1. Instalar dependencias con `winget` o `choco`:
```powershell
winget install -e --id Docker.DockerDesktop
winget install -e --id Kubernetes.minikube
winget install -e --id Kubernetes.kubectl
winget install -e --id AquaSecurity.Trivy
```

2. Descargar binarios de:
- Conftest → https://github.com/open-policy-agent/conftest/releases  
- Kyverno CLI → https://github.com/kyverno/kyverno/releases  

   Descomprimir en:
   ```
   C:\tools\conftest
   C:\tools\kyverno
   ```
   Agregar esas carpetas al **PATH** (Variables de entorno → Path).

3. Verificar:
```powershell
docker version
minikube version
kubectl version --client
trivy -v
conftest --version
kyverno version
```

---

### macOS (Homebrew)
```bash
brew install --cask docker
brew install minikube kubectl trivy
brew tap instrumenta/instrumenta && brew install conftest
brew install kyverno
```

---

### Linux (Debian/Ubuntu)
```bash
# Docker
sudo apt-get update
sudo apt-get install -y docker.io

# Minikube y kubectl
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Trivy
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy

# Conftest
wget https://github.com/open-policy-agent/conftest/releases/download/v0.56.0/conftest_0.56.0_Linux_x86_64.tar.gz
tar xzf conftest_0.56.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Kyverno CLI
wget https://github.com/kyverno/kyverno/releases/download/v1.12.0/kyverno-cli_v1.12.0_linux_x86_64.tar.gz
tar xzf kyverno-cli_v1.12.0_linux_x86_64.tar.gz
sudo mv kyverno /usr/local/bin/
```

---

## 📂 Estructura del repositorio

```
kcdBogotaColombia/
├─ README.md
├─ docs/
│  └─ 00_intro.md
├─ src/
│  ├─ main.go
│  └─ Dockerfile
├─ k8s/
│  ├─ namespace.yaml
│  ├─ deployment.yaml
│  └─ service.yaml
├─ policies/
│  ├─ opa/
│  │  └─ policy.rego
│  └─ kyverno/
│     ├─ require-requests-limits.yaml
│     ├─ disallow-latest-tag.yaml
│     └─ default-seccomp.yaml
├─ logging/
│  └─ fluentd/
│     ├─ ns.yaml
│     ├─ configmap.yaml
│     └─ daemonset.yaml
└─ .github/
   └─ workflows/
      ├─ trivy.yml
      └─ policy-checks.yml
```

---

## 0) Preparación
**Narrativa:**  
> “Vamos a simular un despliegue apurado. La idea es que los escudos eviten que algo débil entre al castillo.”

Verifica que las herramientas están instaladas:
```powershell
docker version
minikube version
kubectl version --client
trivy -v
conftest --version
kyverno version
```

---

## 1) Levantar el castillo (clúster) y el barrio (namespace)
```powershell
minikube delete -p kcd-castle
minikube start -p kcd-castle --driver=docker --cpus=2 --memory=4096
kubectl config current-context
kubectl get nodes
kubectl apply -f k8s/namespace.yaml
kubectl get ns
```

✅ *Checkpoint:* Nodo `Ready` y namespace creado.

---

## 2) El desarrollador apurado: build + deploy
```powershell
docker build -t kcd-app:local src
minikube -p kcd-castle image load kcd-app:local
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl -n app rollout status deployment/kcd-app
kubectl -n app get pods,svc
```

✅ *Checkpoint:* pods `Running`.

---

```bash
# Verificar que los pods están corriendo
kubectl -n app get pods

# Hacer port-forward del Service hacia localhost:8080
kubectl -n app port-forward svc/kcd-app 8080:80

# En otra terminal (Linux/macOS)
curl http://localhost:8080

# En otra terminal (Windows PowerShell)
Invoke-WebRequest http://localhost:8080 -UseBasicParsing

# Ver logs generados por la app
kubectl -n app logs -l app=kcd-app --tail=20

# Alternativa: exponer directamente con minikube
minikube -p kcd-castle service kcd-app -n app --url
```

---

## 3) Escudo 1 — Trivy
```powershell
trivy fs --exit-code 0 --no-progress .
trivy config --exit-code 1 --severity HIGH,CRITICAL k8s
trivy image --severity HIGH,CRITICAL kcd-app:local
```

**Narrativa:**  
> “Trivy detecta vulnerabilidades y configuraciones débiles **antes** de la batalla.”

---

## 4) Escudo 2 — OPA/Conftest
```powershell
conftest test k8s/deployment.yaml -p policies/opa
```

- Si quieres mostrar fallos: quita `resources.limits` en el YAML y vuelve a correr.

**Narrativa:**  
> “OPA valida en la puerta: si no cumples las reglas, no pasas.”

---

## 5) Escudo 3 — Kyverno
Instalar Kyverno y aplicar políticas:
```powershell
kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/install.yaml
kubectl -n kyverno get pods
kubectl apply -f policies/kyverno/
kubectl get cpol
```

Probar un manifiesto “malo”:
```powershell
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-deploy
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels: { app: bad-deploy }
  template:
    metadata:
      labels: { app: bad-deploy }
    spec:
      containers:
      - name: c
        image: nginx:latest
"@ | Out-File .\bad-deploy.yaml -Encoding utf8

kubectl apply -f .\bad-deploy.yaml
```

✅ Kyverno lo rechaza con mensaje de error.

**Narrativa:**  
> “Dentro del castillo, las leyes del reino se hacen cumplir.”

---

## 6) Escudo 4 — Fluentd
Desplegar Fluentd:
```powershell
kubectl apply -f logging/fluentd/ns.yaml
kubectl apply -f logging/fluentd/configmap.yaml
kubectl apply -f logging/fluentd/daemonset.yaml
kubectl -n logging get pods
```

Generar tráfico y revisar logs:
```powershell
kubectl -n app port-forward svc/kcd-app 8080:80
Invoke-WebRequest http://localhost:8080 -UseBasicParsing
kubectl -n logging logs -l app=fluentd -f --tail=100
```

**Narrativa:**  
> “Los vigías en las torres reportan todo lo que pasa dentro del castillo.”

---

## 7) Cierre
- **Trivy** → detecta vulnerabilidades antes.  
- **OPA/Conftest** → valida manifiestos previos.  
- **Kyverno** → hace cumplir las leyes.  
- **Fluentd** → centraliza visibilidad.  

**Mensaje final:**  
> “La seguridad no es un muro, es un sistema de defensas en capas. Así construimos castillos impenetrables.”

---

## 🧹 Limpieza
```powershell
kubectl delete -f logging/fluentd/daemonset.yaml
kubectl delete -f logging/fluentd/configmap.yaml
kubectl delete -f logging/fluentd/ns.yaml
kubectl delete -f policies/kyverno/
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/namespace.yaml
minikube delete -p kcd-castle
```
