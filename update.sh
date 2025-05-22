#!/opt/bin/sh

# Выйти при любой ошибке
set -e

# Определение переменных
SCRIPT_PATH="/opt/etc/nfqws/update.sh"
TMP_UPDATE="/opt/tmp/update.sh"
TMP_DOMAINS="/opt/tmp/domains_all.txt"
EXCLUDE_LIST="/opt/tmp/exclude.list"
USER_LIST="/opt/etc/nfqws/user.list"
UPDATE_URL="https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update.sh "
DOMAINS_URL="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst "
LOG_FILE="/opt/var/log/nfqws_update.log"

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Начало работы скрипта
log "Запуск скрипта обновления."

# Загрузка нового скрипта
log "Загрузка обновления скрипта с $UPDATE_URL."
if ! curl -sf -o "$TMP_UPDATE" "$UPDATE_URL"; then
    log "Ошибка: Не удалось загрузить скрипт обновления."
    exit 1
fi

# Проверка наличия shebang в загруженном скрипте
if head -n 1 "$TMP_UPDATE" | grep -q '^#!/'; then
    log "Загруженный скрипт содержит shebang."
else
    log "Ошибка: Загруженный скрипт не содержит shebang или повреждён."
    rm "$TMP_UPDATE"
    exit 1
fi

# Функция для обновления скрипта
update_script() {
    log "Обновление скрипта."
    mv "$TMP_UPDATE" "$SCRIPT_PATH" || { log "Ошибка: Не удалось переместить скрипт."; exit 1; }
    chmod +x "$SCRIPT_PATH" || { log "Ошибка: Не удалось установить права на выполнение."; exit 1; }

    # Проверка существования и прав на новый скрипт
    if [ -x "$SCRIPT_PATH" ]; then
        log "Скрипт обновлён успешно. Перезапуск."
        # Логирование прав доступа
        ls -l "$SCRIPT_PATH" >> "$LOG_FILE"
        # Исполнение нового скрипта через /bin/sh
        exec /bin/sh "$SCRIPT_PATH"
        exit 0
    else
        log "Ошибка: Обновлённый скрипт не является исполняемым."
        exit 1
    fi
}

# Проверка, существует ли текущий скрипт
if [ -f "$SCRIPT_PATH" ]; then
    # Сравнение загруженного скрипта с текущим
    if ! cmp -s "$TMP_UPDATE" "$SCRIPT_PATH"; then
        log "Обнаружены изменения в скрипте. Обновление необходимо."
        update_script
    else
        log "Скрипт обновления не изменился."
        rm "$TMP_UPDATE"
    fi
else
    # Если текущий скрипт отсутствует, установить новый
    log "Текущий скрипт не найден. Установка нового скрипта."
    update_script
fi

# Продолжение выполнения основного скрипта

# Загрузка списка доменов
log "Загрузка списка доменов с $DOMAINS_URL."
if ! curl -sf -o "$TMP_DOMAINS" "$DOMAINS_URL"; then
    log "Ошибка: Не удалось загрузить список доменов."
    exit 1
fi

# Загрузка списка исключений
log "Загрузка списка исключений с https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/exclude.lst "
if ! curl -sf -o "$EXCLUDE_LIST" "https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/exclude.lst "; then
    log "Ошибка: Не удалось загрузить список исключений."
    exit 1
fi

# Удаление поддоменов и исключение нежелательных доменов
log "Обработка списка доменов: удаление поддоменов и исключение нежелательных."

awk '
BEGIN {
    # Чтение исключений в массив exclude
    while ((getline line < "'"$EXCLUDE_LIST"'") > 0) {
        if (line != "") {
            exclude[line] = 1
        }
    }
    close("'"$EXCLUDE_LIST"'")
}

{
    domain[$0] = 1
}
END {
    for (d in domain) {
        # Пропустить, если домен в списке исключения
        if (exclude[d]) continue

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

log "Список пользователей обновлён: $USER_LIST."

# Перезапуск службы
log "Перезапуск службы S51nfqws."
if /opt/etc/init.d/S51nfqws restart; then
    log "Служба S51nfqws успешно перезапущена."
else
    log "Ошибка: Не удалось перезапустить службу S51nfqws."
    exit 1
fi

# Очистка временных файлов
rm -f "$TMP_DOMAINS" "$EXCLUDE_LIST"

log "Скрипт обновления завершён успешно."

exit 0
