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
### Repository Structure
```
.
├── .github/workflows/
│   └── ci-cd.yaml             # CI/CD pipeline for build, push, and deploy
├── k8s/
│   ├── app-deployment.yaml    # NestJS app Deployment
│   ├── app-service.yaml       # Service exposing the NestJS pods
│   ├── app-ingress.yaml       # Ingress for external access
│   ├── configmap.yaml         # App configuration (non-secret)
│   ├── secret.yaml            # Sensitive credentials (Redis password)
│   ├── redis-deployment.yaml  # Redis Deployment
│   ├── redis-service.yaml     # Redis Service
│   ├── redis-exporter.yaml    # Redis Exporter for Prometheus
│   ├── prometheus.yaml        # Prometheus core configuration
│   ├── prometheus-setup.yaml  # Prometheus Operator setup
│   ├── prometheus-service.yaml# Prometheus Service
│   ├── grafana.yaml           # Grafana Deployment and Service
│   ├── grafana-datasource.yaml# Grafana Prometheus datasource config
│   ├── nestjs-service-monitor.yaml # ServiceMonitor for NestJS metrics
│   ├── redis-service-monitor.yaml  # ServiceMonitor for Redis exporter
│   ├── hpa.yaml               # Horizontal Pod Autoscaler for NestJS
│   └── ...                    # Additional monitoring and RBAC configs
├── src/
│   ├── app.controller.ts
│   ├── app.service.ts
│   ├── app.module.ts
│   ├── main.ts
│   ├── metrics/               # Prometheus metrics integration
│   └── redis/                 # Redis connection and health check logic
├── Dockerfile                 # Multi-stage optimized build
├── .dockerignore
├── .env                       # Environment variables
├── README.md                  # Project documentation (this file)
└── package.json
```

## 🐳 Docker Setup

### Multi-Stage Dockerfile

The Dockerfile uses a multi-stage approach to minimize the final image size and improve security.

Build Stage
- Uses official node:18-alpine base image
- Installs only production dependencies
- Compiles the TypeScript code

### Runtime Stage
- Uses node:18-alpine again (clean and minimal)
- Copies built files from the builder stage
- Runs the application as a non-root user
- Exposes port 3000

### This approach:
- Reduces the image size from ~900MB to ~120MB
- Avoids including dev dependencies
- Eliminates root privileges in containers (security best practice)

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
### CI/CD Pipeline – GitHub Actions

Located in .github/workflows/ci-cd.yaml.

### Pipeline Stages

1. Checkout Code
```
- uses: actions/checkout@v3
```
2. Build Docker Image
```
- run: docker build -t ghcr.io/<user>/nestjs-app:latest .
```
3. Push to Container Registry
```
- run: docker push ghcr.io/<user>/nestjs-app:latest
```
4. Deploy to Kubernetes
```
- run: kubectl apply -f k8s/
```
### Secrets Used
- REGISTRY_USERNAME
- REGISTRY_PASSWORD
- KUBECONFIG or service account credentials
The pipeline ensures automated image builds, version tagging, and zero-downtime rolling updates in Kubernetes.
---
### Kubernetes Components

Namespaces

All application components are deployed in the default namespace, while monitoring components are in monitoring.

### Application Resources
```
kubectl get pods
NAME                          READY   STATUS    RESTARTS   AGE
nestjs-app-85f766bcf8-grs4g   1/1     Running   0          3h50m
nestjs-app-85f766bcf8-xtjnq   1/1     Running   0          3h50m
redis-677db94665-7fpv7        1/1     Running   0          3h50m
```
### Monitoring Stack
```
kubectl get pods -n monitoring
NAME                                                      READY   STATUS    RESTARTS   AGE
alertmanager-prometheus-operator-kube-p-alertmanager-0    2/2     Running   0          24h
grafana-65d4678654-86xrg                                  1/1     Running   0          4h49m
prometheus-prometheus-operator-kube-p-prometheus-0        2/2     Running   0          117m
redis-exporter-5b945f7d98-mchvk                           1/1     Running   0          114m
```
### Key Resources

- Deployment: Scalable NestJS and Redis pods
- Service: ClusterIP services exposing internal endpoints
- Ingress: External access to the NestJS API
- ConfigMap / Secret: Configuration and Redis credentials
- HPA: Automatically scales the app based on CPU utilization
- ServiceMonitor: Integrates NestJS and Redis metrics with Prometheus

### Redis Integration

The application connects to Redis using environment variables defined in:

- .env
- k8s/configmap.yaml
- k8s/secret.yaml

### Validation Command
```
kubectl port-forward service/nestjs-app 3001:3000
curl http://localhost:3001/redis
```
### Response:
```
{"status":true,"message":"Redis connection is healthy"}
```
This confirms that Redis is reachable and the NestJS service is functioning correctly.

### Monitoring Setup

Prometheus

- Monitors NestJS and Redis via /metrics endpoint.
- Collects CPU, memory, and application-level metrics.

### Grafana

- Connected to Prometheus as a datasource.
- Includes dashboards for:
  - API latency
  - CPU / Memory usage
  - Redis health
  - Application-level metrics (NestJS)

### Service Monitors

- nestjs-service-monitor.yaml — scrapes metrics from the NestJS pods
- redis-service-monitor.yaml — scrapes metrics from Redis exporter

### Security and Best Practices

- Non-root user in Dockerfile (ensures privilege isolation)
- Kubernetes Secrets for credentials
- NetworkPolicy (optional) restricts cross-namespace access
- SecurityContext prevents privilege escalation
- Resource Requests/Limits prevent resource starvation

### Scaling and Resilience

- Implemented Horizontal Pod Autoscaler (HPA):
- Monitors CPU usage
- Scales NestJS pods between 1 and 5 replicas
- Ensures application stability under varying load

### Testing and Verification

After deployment:
```
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl logs deployment/nestjs-app
kubectl port-forward service/nestjs-app 3001:3000
curl http://localhost:3001/redis
```

Health check endpoint:
```
/redis → verifies Redis connectivity
/metrics → exposes Prometheus metrics
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
### Why This Architecture

This solution was designed with real-world DevOps production standards:

### How to Deploy
```
# Build and push image
docker build -t ghcr.io/<user>/nestjs-app:latest .
docker push ghcr.io/<user>/nestjs-app:latest

# Apply Kubernetes manifests
kubectl apply -f k8s/

# Verify deployment
kubectl get pods
kubectl get services
kubectl get ingress
```

### Project Validation Output

Example of live cluster verification:
```
kubectl get pods
nestjs-app-85f766bcf8-grs4g   1/1     Running   0   3h50m
nestjs-app-85f766bcf8-xtjnq   1/1     Running   0   3h50m
redis-677db94665-7fpv7        1/1     Running   0   3h50m

kubectl get pods -n monitoring
grafana-65d4678654-86xrg      1/1     Running   0   4h49m
prometheus-prometheus-0       2/2     Running   0   90m
redis-exporter-5b945f7d98     1/1     Running   0   114m
```

### Conclusion

This repository demonstrates a complete DevOps-ready microservice setup.
It includes:
- Lightweight and secure containers
- Automated CI/CD pipeline
- Kubernetes manifests following best practices
- Integrated observability with Prometheus and Grafana
- Scalable and resilient architecture with Redis
---

### Author
**DevOps Engineer:** Vlad Klymenchenko  
**Company:** Nova Poshta  
**Cloud:** Google Kubernetes Engine (GKE)
