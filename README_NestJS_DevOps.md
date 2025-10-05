# NestJS + Redis + Kubernetes + CI/CD + Monitoring

## 🧠 Опис проекту

Цей проєкт демонструє **повний DevOps-потік** для NestJS застосунку з інтеграцією Redis, CI/CD, моніторингом через Prometheus + Grafana, та розгортанням у Kubernetes.

---

## ⚙️ Архітектура

```
┌───────────────────────────────────────┐
│               GitHub/GitLab           │
│        (CI/CD: Build → Push → Deploy) │
└───────────────────────────────────────┘
                  │
                  ▼
┌───────────────────────────────────────┐
│           Docker Registry             │
│     (Docker Hub / GHCR / GCR)         │
└───────────────────────────────────────┘
                  │
                  ▼
┌───────────────────────────────────────┐
│           Kubernetes Cluster          │
│ ┌────────────┐   ┌──────────────┐     │
│ │ NestJS App │ → │ Redis (DB)   │     │
│ └────────────┘   └──────────────┘     │
│      │ Metrics         │              │
│      ▼                 ▼              │
│ Prometheus ←→ Grafana (Dashboards)    │
└───────────────────────────────────────┘
```

---

## 🧠 Перевірка підключення Redis

```bash
kubectl port-forward service/nestjs-app 3001:3000
curl http://localhost:3001/redis
# {"status":true,"message":"Redis connection is healthy"}
```

---

## 📊 Моніторинг (Prometheus + Grafana)

| Метрика | Запит | Опис |
|----------|-------|------|
| CPU usage | `rate(process_cpu_seconds_total{{job="nestjs-app"}}[5m])` | Використання CPU |
| Memory | `process_resident_memory_bytes{{job="nestjs-app"}}` | Використання пам’яті |
| Uptime | `process_start_time_seconds{{job="nestjs-app"}}` | Час старту процесу |
| HTTP requests | `http_server_requests_total{{job="nestjs-app"}}` | Кількість HTTP запитів |

---

## 📘 Результати тестування

```
$ kubectl get pods
nestjs-app-85f766bcf8-grs4g   1/1     Running   0     3h50m
nestjs-app-85f766bcf8-xtjnq   1/1     Running   0     3h50m
redis-677db94665-7fpv7        1/1     Running   0     3h50m

$ curl http://localhost:3001/redis
{"status":true,"message":"Redis connection is healthy"}
```

---

🕒 Оновлено: 2025-10-05 15:33:36
