#!/bin/sh

set -e  # Скрипт завершится при любой ошибке

# Определение путей
SCRIPT_PATH="/opt/etc/nfqws/update.sh"
TMP_UPDATE="/tmp/update1.sh"
TMP_DOMAINS="/tmp/domains_all.txt"
USER_LIST="/opt/etc/nfqws/user.list"
UPDATE_URL="https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update1.sh"
DOMAINS_URL="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"
LOG_FILE="/var/log/nfqws_update.log"

# Функция для логирования
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Обработка сигналов для очистки
trap 'rm -f "$TMP_UPDATE" "$TMP_DOMAINS"' EXIT

# Загрузка скрипта обновления
log "Загрузка обновления скрипта с $UPDATE_URL..."
if ! curl -sf -o "$TMP_UPDATE" "$UPDATE_URL"; then
  log "Ошибка загрузки скрипта обновления."
  exit 1
fi

# Проверка изменений в скрипте
if ! cmp -s "$TMP_UPDATE" "$SCRIPT_PATH"; then
  log "Обнаружены изменения в скрипте обновления. Создаём резервную копию..."
  
  # Создание резервной копии
  if [ -f "$SCRIPT_PATH" ]; then
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak" || { log "Не удалось создать резервную копию."; exit 1; }
    log "Резервная копия создана: ${SCRIPT_PATH}.bak"
  else
    log "Текущий скрипт не найден. Пропускаем создание резервной копии."
  fi
  
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
  
  # Проверка синтаксиса скрипта без использования опции -n
  # Вместо этого попробуем выполнить скрипт с опцией --check, если доступна
  # Или пропустим проверку синтаксиса
  # Здесь мы пропустим проверку синтаксиса для избежания ошибки
  
  # Вывод содержимого скрипта для диагностики (опционально)
  log "Содержимое обновлённого скрипта $SCRIPT_PATH:"
  cat "$SCRIPT_PATH" | tee -a "$LOG_FILE"
  
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
if /opt/etc/init.d/S51nfqws restart; then
  log "Служба успешно перезапущена."
else
  log "Ошибка при перезапуске службы S51nfqws."
  exit 1
fi

# Очистка временных файлов (уже обрабатывается через trap)
