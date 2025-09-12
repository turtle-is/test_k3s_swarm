# K3s vs Docker Swarm на RISC-V: CPU-бенчмарки со stress-ng

Набор скриптов и манифестов для сравнения **K3s** и **Docker Swarm** на CPU-bound нагрузке (интенсивные матричные вычисления `matrixprod` из `stress-ng`) на архитектуре **RISC-V**.

## Что тут есть

- **docker/** — `Dockerfile` с `stress-ng`, `time`, `numactl`, `lscpu` + `src/entrypoint.sh`.
- **k3s/** — `job.yaml` и скрипт автоматических прогонов `run_k3s_bench.sh`.
- **swarm/** — `stack.yaml` и скрипт автоматических прогонов `run_swarm_bench.sh`.
- **parse_results.py** — сбор метрик из папок результатов в единый `summary.csv`.
- **README.md** — это описание.

## Зависимости/предпосылки

- Узел(ы) Linux на **RISC-V**, установлен **Docker** и кластер **K3s** (или другой совместимый Kubernetes).
- Доступ к `kubectl` (настроенный kubeconfig) и/или `docker swarm` (инициализирован).
- На ноде достаточно CPU (1–4 vCPU свободных) и прав для монтирования `hostPath`/volume.

Образ по умолчанию: `nctortue/riscv-stress-ng:latest`  
(можно пересобрать: `docker build -t <user>/riscv-stress-ng:latest -f docker/Dockerfile .` и запушить в Docker Hub).

## Что делает тест

Запускает `stress-ng` со стрессором `cpu` и методом `matrixprod`:

```bash
stress-ng --cpu <N> --cpu-method matrixprod --metrics-brief --timeout <DURATION>



kubectl apply -f k3s/job.yaml
kubectl wait --timeout=15m --for=condition=complete job/stress-ng-bench
# результаты: /var/bench-results/k3s/...



docker stack deploy -c swarm/stack.yaml stressbench
docker service logs -f stressbench_stress
# результаты: /var/bench-results/swarm/...
docker stack rm stressbench



cd k3s
chmod +x run_k3s_bench.sh
# Параметры по умолчанию: RUNS=3, VCPUS=3, DURATION=600s, K8S_NODE=lpi4aserver
RUNS=3 VCPUS=3 DURATION=600s ./run_k3s_bench.sh

# результаты по прогонам:
sudo ls -1dt /var/bench-results/k3s/k3s-*-run*


cd swarm
chmod +x run_swarm_bench.sh
# Параметры по умолчанию: RUNS=3, VCPUS=3, DURATION=600s, SWARM_NODE=lpi4aServer
RUNS=3 VCPUS=3 DURATION=600s ./run_swarm_bench.sh

# результаты по прогонам:
sudo ls -1dt /var/bench-results/swarm/swarm-*-run*



python3 parse_results.py
