
# 🏰 Workshop — “El despliegue apurado del desarrollador”

## 🎯 Objetivo
Simular un despliegue inseguro y mostrar cómo los **4 escudos** (Trivy, OPA/Conftest, Kyverno y Fluentd) protegen al clúster en diferentes etapas.

---

## 0) Preparación (2–3 min)
**Narrativa:**  
> “Vamos a simular un despliegue apurado. La idea es que los escudos eviten que algo débil entre al castillo.”

**Verifica herramientas:**
```powershell
docker version
minikube version
kubectl version --client
trivy -v
conftest --version
kyverno version
```

---

## 1) Levantar el castillo (clúster) y el barrio (namespace) (3–4 min)
```powershell
minikube delete -p kcd-castle
minikube start -p kcd-castle --driver=docker --cpus=2 --memory=4096
kubectl config current-context
kubectl get nodes
kubectl apply -f apps\sample-app\k8s\namespace.yaml
kubectl get ns
```

✅ *Checkpoint:* Nodo `Ready` y namespace `app` creado.

---

## 2) El desarrollador apurado: build + deploy (4–5 min)
```powershell
docker build -t sample-app:local apps\sample-app
minikube -p kcd-castle image load sample-app:local
kubectl apply -f apps\sample-app\k8s\deployment.yaml
kubectl apply -f apps\sample-app\k8s\service.yaml
kubectl -n app rollout status deployment/sample-app
kubectl -n app get pods,svc
```

✅ *Checkpoint:* 2 pods `Running`.

---

## 3) Escudo 1 — Trivy (4–5 min)
```powershell
trivy fs --exit-code 0 --no-progress .
trivy config --exit-code 1 --severity HIGH,CRITICAL apps\sample-app\k8s
trivy image --severity HIGH,CRITICAL sample-app:local
```

**Narrativa:**  
> “Trivy detecta vulnerabilidades y configuraciones débiles **antes** de la batalla.”

---

## 4) Escudo 2 — OPA/Conftest (4–5 min)
```powershell
conftest test apps\sample-app\k8s\deployment.yaml -p policies\opa
```

- Si quieres forzar errores: quita `resources.limits` en el YAML y vuelve a correr.

**Narrativa:**  
> “OPA valida en la puerta: si no cumples las reglas, no pasas.”

---

## 5) Escudo 3 — Kyverno (6–7 min)
Instala y aplica políticas:
```powershell
kubectl apply -f https://raw.githubusercontent.com/kyverno/kyverno/main/config/install.yaml
kubectl -n kyverno get pods
kubectl apply -f policies\kyverno\require-requests-limits.yaml
kubectl apply -f policies\kyverno\disallow-latest-tag.yaml
kubectl apply -f policies\kyverno\default-seccomp.yaml
kubectl get cpol
```

Prueba un deployment “malo”:
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

✅ *Checkpoint:* Kyverno rechaza el manifiesto con error “must not use :latest”.

**Narrativa:**  
> “Dentro del castillo, las leyes del reino se hacen cumplir.”

---

## 6) Escudo 4 — Fluentd (5–6 min)
Despliega Fluentd:
```powershell
kubectl apply -f logging\fluentd\ns.yaml
kubectl apply -f logging\fluentd\configmap.yaml
kubectl apply -f logging\fluentd\daemonset.yaml
kubectl -n logging get daemonset
kubectl -n logging get pods -o wide
```

Genera tráfico y revisa logs:
```powershell
kubectl -n app port-forward svc/sample-app 8080:80
Invoke-WebRequest http://localhost:8080 -UseBasicParsing
kubectl -n logging logs -l app=fluentd -f --tail=100
```

**Narrativa:**  
> “Los vigías en las torres reportan todo lo que pasa dentro del castillo.”

---

## 7) Cierre (1–2 min)
**Resumen:**  
- **Trivy** → detecta vulnerabilidades antes.  
- **OPA/Conftest** → evita manifiestos inseguros en la puerta.  
- **Kyverno** → aplica las leyes dentro del clúster.  
- **Fluentd** → nos da visibilidad centralizada.  

**Mensaje final:**  
> “La seguridad no es un muro, es un sistema de defensas en capas. Así construimos castillos impenetrables.”

---

## 🧹 Limpieza (opcional)
```powershell
kubectl delete -f logging\fluentd\daemonset.yaml
kubectl delete -f logging\fluentd\configmap.yaml
kubectl delete -f logging\fluentd\ns.yaml
kubectl delete -f policies\kyverno\default-seccomp.yaml
kubectl delete -f policies\kyverno\disallow-latest-tag.yaml
kubectl delete -f policies\kyverno\require-requests-limits.yaml
kubectl delete -f apps\sample-app\k8s\service.yaml
kubectl delete -f apps\sample-app\k8s\deployment.yaml
kubectl delete -f apps\sample-app\k8s\namespace.yaml
minikube delete -p kcd-castle
```
