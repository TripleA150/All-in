#!/bin/sh

set -e  # Скрипт будет завершаться при любой ошибке

# Определение путей
SCRIPT_PATH="/opt/etc/nfqws/update.sh"
TMP_UPDATE="/tmp/update.sh"
TMP_DOMAINS="/tmp/domains_all.txt"
USER_LIST="/opt/etc/nfqws/user.list"
UPDATE_URL="https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update.sh"
DOMAINS_URL="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"

# Функция для логирования
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Загрузка скрипта обновления
if ! curl -sf -o "$TMP_UPDATE" "$UPDATE_URL"; then
  log "Ошибка загрузки скрипта обновления."
  exit 1
fi

# Проверка изменений в скрипте
if ! cmp -s "$TMP_UPDATE" "$SCRIPT_PATH"; then
  log "Обнаружены изменения в скрипте обновления. Обновление..."
  mv "$TMP_UPDATE" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  log "Скрипт обновлён. Перезапуск..."
  exec "$SCRIPT_PATH"  # Перезапуск обновлённого скрипта
  exit
else
  log "Скрипт обновления не изменился."
  rm "$TMP_UPDATE"
fi

# Загрузка списка доменов
log "Загрузка списка доменов..."
if ! curl -sf -o "$TMP_DOMAINS" "$DOMAINS_URL"; then
  log "Ошибка загрузки списка доменов."
  exit 1
fi

# Удаление поддоменов
log "Удаление поддоменов из списка..."
awk '
{
  domain[$0] = 1
}
END {
  for (d in domain) {
    skip = 0
    temp = d
    while (match(temp, /\.[^.]+$/)) {
      temp = substr(temp, RSTART + 1)
      if (domain[temp]) {
        skip = 1
        break
      }
    }
    if (!skip) print d
  }
}' "$TMP_DOMAINS" > "$USER_LIST"

log "Список пользователей обновлён: $USER_LIST"

# Перезапуск службы
log "Перезапуск службы S51nfqws..."
/opt/etc/init.d/S51nfqws restart
log "Служба перезапущена успешно."

# Очистка временных файлов
rm -f "$TMP_DOMAINS"