#!/usr/bin/env bash

LOG_FILE="access.log"

IPS=("192.168.1.10" "10.0.0.5" "172.16.0.22" "192.168.1.45" "10.0.0.18" "203.0.113.7")
METHODS=("GET" "POST" "PUT" "DELETE")
ENDPOINTS=("/api/users" "/api/login" "/api/orders" "/api/status" "/api/items")
STATUSES=(200 200 200 201 400 401 403 404 500 502)

# Генерация 350 строк логов
> "$LOG_FILE"
for i in $(seq 1 350); do
    # Искусственно делаем первые два IP более частыми для наглядного топ-3
    if (( i % 3 == 0 )); then
        ip="192.168.1.10"
    elif (( i % 4 == 0 )); then
        ip="10.0.0.5"
    else
        ip=${IPS[$((RANDOM % ${#IPS[@]}))]}
    fi

    method=${METHODS[$((RANDOM % ${#METHODS[@]}))]}
    endpoint=${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}
    status=${STATUSES[$((RANDOM % ${#STATUSES[@]}))]}

    hour=$(printf "%02d" $((10 + (i / 60) % 12)))
    min=$(printf "%02d" $((i % 60)))
    sec=$(printf "%02d" $(((i * 7) % 60)))

    echo "$ip - - [15/Aug/2026:$hour:$min:$sec] \"$method $endpoint HTTP/1.1\" $status" >> "$LOG_FILE"
done

echo "Сгенерирован файл $LOG_FILE ($(wc -l < "$LOG_FILE") строк)"
echo "----------------------------------------"

# 1. Общее количество запросов (с проверкой формата строки через регулярное выражение)
TOTAL_REQUESTS=$(grep -Ec '^[0-9]{1,3}(\.[0-9]{1,3}){3} - - \[.*\] "[A-Z]+ .* HTTP/[0-9.]+" [0-9]{3}$' "$LOG_FILE")
echo "Общее количество запросов: $TOTAL_REQUESTS"

# 2. Топ-3 IP-адреса (парсинг IP регулярным выражением + sort/uniq/awk)
echo "Топ-3 IP-адреса по количеству запросов:"
grep -Eo '^([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_FILE" \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -n 3 \
    | awk '{printf "  %d. %s (%s запросов)\n", NR, $2, $1}'

# 3. Количество запросов с кодами 4xx и 5xx (фильтрация по последнему полю через awk + regex)
ERROR_4XX=$(awk '$NF ~ /^4[0-9]{2}$/ {count++} END {print count+0}' "$LOG_FILE")
ERROR_5XX=$(awk '$NF ~ /^5[0-9]{2}$/ {count++} END {print count+0}' "$LOG_FILE")
TOTAL_ERRORS=$(awk '$NF ~ /^[45][0-9]{2}$/ {count++} END {print count+0}' "$LOG_FILE")

echo "Запросов с кодами 4xx: $ERROR_4XX"
echo "Запросов с кодами 5xx: $ERROR_5XX"
echo "Всего ошибок (4xx и 5xx): $TOTAL_ERRORS"