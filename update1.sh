#!/bin/sh

set -e  # Выход при любой ошибке

# Определение путей
SCRIPT_PATH="/opt/etc/nfqws/update.sh"
TMP_UPDATE="/tmp/update.sh"
TMP_DOMAINS="/tmp/domains_all.txt"
USER_LIST="/opt/etc/nfqws/user.list"
UPDATE_URL="https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update1.sh"
DOMAINS_URL="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"

# Функция для логирования
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Загрузка скрипта обновления
log "Загрузка обновления скрипта с $UPDATE_URL..."
if ! curl -sf -o "$TMP_UPDATE" "$UPDATE_URL"; then
  log "Ошибка загрузки скрипта обновления."
  exit 1
fi

# Проверка изменений в скрипте
if ! cmp -s "$TMP_UPDATE" "$SCRIPT_PATH"; then
  log "Обнаружены изменения в скрипте обновления. Создаём резервную копию..."
  cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak" || { log "Не удалось создать резервную копию."; exit 1; }
  
  log "Обновляем скрипт..."
  mv "$TMP_UPDATE" "$SCRIPT_PATH" || { log "Не удалось переместить обновлённый скрипт."; exit 1; }
  chmod +x "$SCRIPT_PATH" || { log "Не удалось установить права на выполнение."; exit 1; }
  
  # Проверка наличия и прав файла
  if [ ! -f "$SCRIPT_PATH" ]; then
    log "Ошибка: обновлённый скрипт не найден."
    mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
    exit 1
  fi
  
  if ! [ -x "$SCRIPT_PATH" ]; then
    log "Ошибка: обновлённый скрипт не имеет прав на выполнение."
    mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
    exit 1
  fi
  
  # Проверка синтаксиса скрипта
  if ! /bin/sh -n "$SCRIPT_PATH"; then
    log "Ошибка: синтаксическая ошибка в обновлённом скрипте."
    mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
    exit 1
  fi
  
  log "Выполняем обновлённый скрипт..."
  exec "$SCRIPT_PATH"
  exit
else
  log "Скрипт обновления не изменился."
  rm "$TMP_UPDATE"
fi

# Загрузка списка доменов
log "Загрузка списка доменов с $DOMAINS_URL..."
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
log "Служба успешно перезапущена."

# Очистка временных файлов
rm -f "$TMP_DOMAINS"
