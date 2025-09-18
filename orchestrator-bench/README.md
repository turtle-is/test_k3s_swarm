# Orchestrator Bench (k3s vs Docker Swarm)

Набор воспроизводимых тестов:
- **L7 (HTTP) нагрузка**: RPS, ошибки, p50/p90/p95/p99.
- **Длительный тест (30 min)**: стабильность и восстановление (под/задача убивается посередине).
- **Системные метрики**: CPU, RAM, NET, DISK из `/proc` (perf не используется).

## Требования
- Python 3.12+ (локально или в контейнере `python:3.12-slim`)
- k3s (сервер+агент) или Docker Swarm (инициализированный), сеть доступна между нодами
- Порт `30081` на серверной ноде свободен

## Запуск

```bash
# поднять сервер
k3s kubectl apply -f l7/k3s/micro-host.yaml
k3s kubectl rollout status deploy/micro-host --timeout=3m

# быстрый L7 прогон
bash l7/k3s/run_l7_k3s.sh

# поднять сервис
bash l7/swarm/deploy_swarm.sh

# быстрый L7 прогон
bash l7/swarm/run_l7_swarm.sh

# k3s:
bash l7/k3s/run_long_k3s.sh

# swarm:
bash l7/swarm/run_long_swarm.sh

python3 l7/metrics/analyze_metrics.py \
  --lat results/k3s_l7_lat.csv --summary results/k3s_l7_summary.json \
  --node results/node_server.csv

