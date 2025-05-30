#!/bin/sh

set -e
curl -k -s -o /opt/etc/nfqws/update_list.sh https://raw.githubusercontent.com/TripleA150/All-in/refs/heads/main/update_list.sh
chmod +x /opt/etc/nfqws/update_list.sh
/opt/etc/nfqws/update_list.sh
