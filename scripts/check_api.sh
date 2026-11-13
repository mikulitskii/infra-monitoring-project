#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 <API_URL>"
    exit 1
fi

URL="$1"

# Выполняем запрос: тихий режим (-s), выходной документ отбрасываем (-o /dev/null),
# выводим только HTTP-код (-w "%{http_code}"), таймаут 10 секунд
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL")

if [ "$HTTP_CODE" -eq 200 ] 2>/dev/null; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: ${HTTP_CODE:-000}"
    exit 1
fi