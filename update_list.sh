#!/bin/sh

OUTPUT="/opt/etc/nfqws/user.list"

TMP_DIR="/tmp/blocklist"
LIST_FILE="$TMP_DIR/domains_all.tmp"
EXCLUDE_FILE="$TMP_DIR/exclude.tmp"
FINAL_FILE="$TMP_DIR/final_list.tmp"

mkdir -p "$TMP_DIR"

rm -f "$LIST_FILE" "$EXCLUDE_FILE" "$FINAL_FILE"

DOMAIN_SOURCE_1="https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst"
DOMAIN_SOURCE_2="https://raw.githubusercontent.com/GubernievS/AntiZapret-VPN/main/setup/root/antizapret/download/include-hosts.txt"

curl -k -s "$DOMAIN_SOURCE_1" >> "$LIST_FILE"
curl -k -s "$DOMAIN_SOURCE_2" >> "$LIST_FILE"

curl -k -s "https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/exclude.lst" > "$EXCLUDE_FILE"

grep -v '^#' "$LIST_FILE" | grep -v '^$' | sed 's/[[:space:]]//g' | sort -u > "$FINAL_FILE"

if [ -s "$EXCLUDE_FILE" ]; then
  grep -vxFf "$EXCLUDE_FILE" "$FINAL_FILE" > "$FINAL_FILE.filtered"
  mv "$FINAL_FILE.filtered" "$FINAL_FILE"
fi

mv "$FINAL_FILE" "$OUTPUT"

killall nfqws
/opt/etc/init.d/S51nfqws start

rm -rf "$TMP_DIR"
