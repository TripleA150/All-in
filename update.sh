#!/bin/sh

SCRIPT_PATH="/opt/etc/nfqws/update.sh"

curl -o /tmp/update.sh https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update.sh

# Проверяем, изменился ли файл
if ! cmp -s /tmp/update.sh "$SCRIPT_PATH"; then
  mv /tmp/update.sh "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  exec "$SCRIPT_PATH" # Перезапускаем обновленный скрипт
  exit
fi

curl -o /tmp/domains_all.txt https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst

# Удаление поддоменов
awk 'BEGIN { FS=OFS="." } {
  domain[$0]=1
} END {
  for (d in domain) {
    skip=0
    n=split(d, parts, ".")
    for (i=2; i<=n; i++) {
      if (domain[parts[i] (i<n ? "." parts[i+1] : "")]) {
        skip=1
        break
      }
    }
    if (!skip) print d
  }
}' /tmp/domains_all.txt > /opt/etc/nfqws/user.list

/opt/etc/init.d/S51nfqws restart
