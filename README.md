# Infra Monitoring Project

Учебный проект по автоматизации мониторинга сервисов, анализу сетевого трафика и логов, контейнеризации стека через Docker Compose и настройке CI/CD в GitHub Actions.

## Структура проекта

```text
.
├── .github/
│   └── workflows/
│       └── ci.yml           # CI-пайплайн проверки синтаксиса и тестов API
├── nginx/
│   └── default.conf         # Конфигурация реверс-прокси Nginx
├── scripts/
│   ├── check_api.sh         # Скрипт проверки доступности HTTP API
│   └── analyze_logs.sh      # Скрипт генерации и парсинга access.log
├── docker-compose.yml       # Описание сервисов api и proxy
├── .gitignore
└── README.md
```

---

## Инструкции по запуску и примеры команд

### 1. Bash-скрипты мониторинга и анализа логов

Выдача прав на выполнение и запуск проверки доступности API:

```bash
chmod +x scripts/check_api.sh scripts/analyze_logs.sh

# Проверка доступного эндпоинта (ожидается код 200, exit code 0)
./scripts/check_api.sh https://httpbin.org/status/200

# Проверка недоступного эндпоинта (ожидается код 404, exit code 1)
./scripts/check_api.sh https://httpbin.org/status/404
```

Генерация тестового `access.log` (350 строк) и вывод статистики (общее число запросов, топ-3 IP-адресов, количество ошибок `4xx` и `5xx`):

```bash
./scripts/analyze_logs.sh
```

### 2. Запуск стека мониторинга в Docker Compose

Стек поднимает бэкенд `api` (`hashicorp/http-echo` на внутреннем порту `8080`) и реверс-прокси `proxy` (`nginx:alpine` на порту `80`) в изолированной сети `monitoring-net`:

```bash
# Запуск контейнеров в фоновом режиме
docker compose up -d

# Проверка статуса сервисов
docker compose ps

# Проверка ответа через Nginx-прокси
curl -i http://localhost:80

# Остановка и удаление контейнеров
docker compose down
```

---

## Деплой на удалённый сервер по SSH и SCP

Ниже приведён алгоритм безопасной настройки доступа без ввода пароля и переноса проекта на удалённый Linux-сервер (`user@server_ip`).

### 1. Генерация пары SSH-ключей (`ssh-keygen`)

На локальной машине создаём криптографическую пару ключей по современному алгоритму `ed25519`:

```bash
ssh-keygen -t ed25519 -C "deploy@infra-monitoring" -f ~/.ssh/id_ed25519
```
* Приватный ключ (`~/.ssh/id_ed25519`) остаётся на локальной машине и никуда не передаётся.
* Публичный ключ (`~/.ssh/id_ed25519.pub`) копируется на целевой сервер.

### 2. Копирование публичного ключа на сервер (`ssh-copy-id`)

Добавляем публичный ключ в `~/.ssh/authorized_keys` на удалённом хосте:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@192.168.1.100
```

Проверка подключения по ключу без ввода пароля:

```bash
ssh -i ~/.ssh/id_ed25519 user@192.168.1.100 "uname -a"
```

### 3. Передача файлов проекта на сервер (`scp` и `tar + ssh`)

#### Вариант А: упаковка в архив и копирование через `scp`

Упаковываем проект (исключая служебную директорию `.git` и временные логи) и отправляем архив на сервер:

```bash
# 1. Создание архива проекта
tar --exclude='.git' --exclude='*.log' --exclude='*.pcapng' -czf infra-monitoring.tar.gz .

# 2. Передача архива по защищённому каналу SCP
scp -i ~/.ssh/id_ed25519 infra-monitoring.tar.gz user@192.168.1.100:/tmp/

# 3. Распаковка на сервере и удаление временного архива
ssh -i ~/.ssh/id_ed25519 user@192.168.1.100 \
  "mkdir -p ~/infra-monitoring-project && tar -xzf /tmp/infra-monitoring.tar.gz -C ~/infra-monitoring-project && rm /tmp/infra-monitoring.tar.gz"
```

#### Вариант Б: потоковая передача без промежуточных файлов (`tar + ssh`)

Передаём поток `tar` напрямую в стандартный ввод удалённой сессии `ssh` одной командой:

```bash
tar --exclude='.git' --exclude='*.log' --exclude='*.pcapng' -czf - . \
  | ssh -i ~/.ssh/id_ed25519 user@192.168.1.100 "mkdir -p ~/infra-monitoring-project && tar -xzf - -C ~/infra-monitoring-project"
```

### 4. Удалённый запуск и проверка после деплоя

После копирования файлов запускаем Docker Compose стек и выполняем проверку работоспособности на сервере:

```bash
ssh -i ~/.ssh/id_ed25519 user@192.168.1.100 << 'REMOTE'
  cd ~/infra-monitoring-project
  chmod +x scripts/*.sh
  docker compose up -d --remove-orphans
  ./scripts/check_api.sh http://localhost:80
REMOTE
```