#!/bin/sh

# Выйти при любой ошибке
set -e

# Определение переменных
SCRIPT_PATH="/opt/etc/nfqws/update.sh"
TMP_UPDATE="/tmp/update.sh"
TMP_DOMAINS="/tmp/domains_all.txt"
USER_LIST="/opt/etc/nfqws/user.list"
UPDATE_URL="https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update.sh"
DOMAINS_URL="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"
LOG_FILE="/var/log/nfqws_update.log"

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Начало работы скрипта
log "Запуск скрипта обновления."

# Загрузка скрипта обновления
log "Загрузка обновления скрипта с $UPDATE_URL..."
if ! curl -sf -o "$TMP_UPDATE" "$UPDATE_URL"; then
    log "Ошибка: Не удалось загрузить скрипт обновления."
    exit 1
fi

# Проверка, изменился ли скрипт
if [ -f "$SCRIPT_PATH" ]; then
    if ! cmp -s "$TMP_UPDATE" "$SCRIPT_PATH"; then
        log "Обнаружены изменения в скрипте обновления. Обновление..."
        mv "$TMP_UPDATE" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        log "Скрипт обновлен. Перезапуск скрипта..."
        exec "$SCRIPT_PATH"
        exit 0
    else
        log "Скрипт обновления не изменился."
        rm "$TMP_UPDATE"
    fi
else
    log "Скрипт обновления отсутствует. Установка нового скрипта..."
    mv "$TMP_UPDATE" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    log "Скрипт обновлен. Перезапуск скрипта..."
    exec "$SCRIPT_PATH"
    exit 0
fi

# Загрузка списка доменов
log "Загрузка списка доменов с $DOMAINS_URL..."
if ! curl -sf -o "$TMP_DOMAINS" "$DOMAINS_URL"; then
    log "Ошибка: Не удалось загрузить список доменов."
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

log "Список пользователей обновлен: $USER_LIST."

# Перезапуск службы
log "Перезапуск службы S51nfqws..."
if /opt/etc/init.d/S51nfqws restart; then
    log "Служба S51nfqws успешно перезапущена."
else
    log "Ошибка: Не удалось перезапустить службу S51nfqws."
    exit 1
fi

# Очистка временных файлов
rm -f "$TMP_DOMAINS"

log "Скрипт обновления завершен успешно."

exit 0
