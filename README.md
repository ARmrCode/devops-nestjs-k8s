# NestJS + Redis + Kubernetes + Prometheus + Grafana Deployment

## Overview

This project demonstrates a **production-grade microservice deployment** of a **NestJS application** integrated with **Redis**, monitored by **Prometheus** and **Grafana**, deployed on **Kubernetes**.  
The setup follows **industry best practices** for containerization, CI/CD, security, observability, and scalability.

---

## 🧩 Architecture

The system includes:
- **NestJS Application** – Node.js-based backend exposing `/redis` and `/metrics` endpoints.
- **Redis** – Caching layer and in-memory database.
- **Prometheus** – Metrics scraping and time-series storage.
- **Grafana** – Visualization and dashboarding tool.
- **Kubernetes (GKE)** – Orchestrates all workloads and handles scaling, networking, and resource management.

### High-level Diagram
```
           ┌─────────────────────┐
           │     Grafana         │
           │   (Visualization)   │
           └────────┬────────────┘
                    │
                    ▼
           ┌─────────────────────┐
           │    Prometheus       │
           │ (Scrapes metrics)   │
           └────────┬────────────┘
                    │
                    ▼
        ┌────────────────────────────┐
        │      NestJS App (x2)       │
        │  /redis, /metrics exposed  │
        └────────┬────────┬──────────┘
                 │        │
                 ▼        ▼
         ┌────────────────────┐
         │      Redis          │
         │   (Data caching)    │
         └────────────────────┘
```

---

## 🐳 Docker Setup

### Multi-Stage Dockerfile

```Dockerfile
# Stage 1: Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Stage 2: Production stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --omit=dev

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000
CMD ["node", "dist/main.js"]
```

✅ **Why this approach:**
- **Multi-stage build** reduces image size by separating build and runtime stages.
- Uses **non-root user** for better security.
- Based on **alpine** for lightweight base image.
- Uses `npm ci` to ensure deterministic dependency resolution.

### .dockerignore
```
node_modules
dist
.git
Dockerfile
README.md
```

---

## ⚙️ Kubernetes Manifests

### Deployment (NestJS App)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nestjs-app
  labels:
    app: nestjs-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nestjs-app
  template:
    metadata:
      labels:
        app: nestjs-app
    spec:
      containers:
      - name: nestjs-app
        image: ghcr.io/username/nestjs-app:latest
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: nestjs-config
        - secretRef:
            name: redis-secret
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 20
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "250m"
            memory: "256Mi"
```

### Service (NestJS App)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nestjs-app
spec:
  selector:
    app: nestjs-app
  ports:
  - protocol: TCP
    port: 3000
    targetPort: 3000
  type: ClusterIP
```

### ServiceMonitor (Prometheus)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nestjs-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nestjs-app
  namespaceSelector:
    matchNames:
    - default
  endpoints:
  - port: http
    interval: 15s
    path: /metrics
```

### Redis Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
```

### Redis Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
```

---

## 🔐 Secrets and Config

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nestjs-config
data:
  NODE_ENV: production
```

### Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
type: Opaque
stringData:
  password: "supersecretpassword"
```

---

## 📈 Monitoring (Prometheus + Grafana)

**Prometheus** automatically scrapes `/metrics` from NestJS and Redis exporters.

**Grafana Dashboard Import:**
- Navigate to Grafana → “+ Import”
- Paste dashboard JSON or ID (e.g., `1860` for Node Exporter Full)
- Select data source: `Prometheus`

**Sample PromQL Queries:**
```promql
process_cpu_seconds_total{job="nestjs-app"}
process_resident_memory_bytes{job="nestjs-app"}
nodejs_eventloop_lag_seconds{job="nestjs-app"}
```

---

## ⚡ CI/CD (GitHub Actions Example)

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: 20
    - name: Build Docker image
      run: docker build -t ghcr.io/${{ github.repository }}:latest .
    - name: Push to GitHub Container Registry
      run: echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
    - run: docker push ghcr.io/${{ github.repository }}:latest
  deploy:
    runs-on: ubuntu-latest
    needs: build
    steps:
    - name: Set up kubectl
      uses: azure/setup-kubectl@v3
    - name: Deploy to Kubernetes
      run: |
        kubectl apply -f k8s/
```

---

## 🧠 Why This Approach

- **Microservice Separation:** Each component (App, Redis, Monitoring) is independent for scalability.
- **Security:** No root users, Secrets for credentials, Network isolation.
- **Observability:** Full metrics pipeline with Prometheus and Grafana.
- **Resilience:** Multi-replica app pods, health checks, autoscaling ready.
- **Efficiency:** Multi-stage Dockerfile and lightweight base images reduce image size.
- **Scalability:** Kubernetes handles horizontal scaling based on CPU/memory.

---

## 🩺 Health Check & Testing

### Verify Pods
```bash
kubectl get pods
```

### Verify Redis Endpoint
```bash
curl http://localhost:3001/redis
# Response: {"status":true,"message":"Redis connection is healthy"}
```

### Verify Metrics
```bash
curl http://localhost:3001/metrics
```

---

## 🔍 Troubleshooting

| Issue | Cause | Fix |
|-------|--------|-----|
| Grafana “no data” | Query syntax error (quotes) | Use single quotes or no quotes in PromQL |
| ServiceMonitor 0/0 targets | Namespace mismatch | Ensure `namespaceSelector.matchNames` includes `default` |
| Redis not connecting | Missing password secret | Check Secret and env in Deployment |
| `ERR_CONNECTION_TIMED_OUT` in browser | Cluster IPs not accessible externally | Use `kubectl port-forward` |

---

## 🚀 Example Commands

```bash
kubectl apply -f k8s/
kubectl get pods -A
kubectl get svc -A
kubectl port-forward service/nestjs-app 3001:3000
```

---

## 📘 Conclusion

This setup demonstrates a **modern DevOps stack** following cloud-native best practices.  
It’s optimized for **security, reliability, scalability, and observability**, and ready for production workloads.

---

### Author
**DevOps Engineer:** Vlad Klymenchenko  
**Company:** Nova Poshta  
**Cloud:** Google Kubernetes Engine (GKE)
