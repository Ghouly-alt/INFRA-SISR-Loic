#!/bin/bash
# verif_supervision.sh - Contrôle complet de la VM SUPERVISION (à lancer en root)
echo "== Services (état / démarrage auto)"; for s in prometheus prometheus-node-exporter grafana-server; do printf '%-26s %-9s %s\n' "$s" "$(systemctl is-active $s)" "$(systemctl is-enabled $s)"; done
echo "== Ports en écoute"; ss -tlnp | grep -E ':(9090|9100|3000) ' | awk '{print $4, $6}'
echo "== Configuration Prometheus"; promtool check config /etc/prometheus/prometheus.yml 2>&1 | grep -E "SUCCESS|FAILED"
echo "== Cibles Prometheus"; curl -s localhost:9090/api/v1/targets | grep -o '"scrapeUrl":"[^"]*"\|"health":"[a-z]*"' | paste - - | sed 's/"scrapeUrl"://; s/"health"://; s/"//g'
echo "== Droits des fichiers sensibles"; ls -l /etc/grafana/ldap.toml /etc/grafana/provisioning/alerting/alertes-*.yaml | awk '{print $1, $3, $4, $9}'
echo "== Grafana : LDAP"; grep -A3 '^\[auth.ldap\]' /etc/grafana/grafana.ini | grep -v '^#'
echo "== Alertes : UID non remplacé (0 attendu) / règles avec gravité (10 attendu)"; cat /etc/grafana/provisioning/alerting/alertes-*.yaml | grep -c "datasourceUid: \(PROM_UID\|TON_UID\)"; cat /etc/grafana/provisioning/alerting/alertes-*.yaml | grep -c "severity:"
echo "== Grafana"; curl -s localhost:3000/api/health | grep -oE '"(database|version)": *"[^"]*"' | tr '\n' ' '; echo
echo "== Conservation Prometheus"; grep -E "^ARGS" /etc/default/prometheus; du -sh /var/lib/prometheus/metrics2
echo "== Heure"; timedatectl timesync-status | grep -E "Server|Leap|Offset"
echo "== Disque /"; df -h / | tail -1 | awk '{print $5" utilisé, "$4" libres"}'
echo "== Noyau et mises à jour en attente"; uname -r; apt list --upgradable 2>/dev/null | grep -vc -e '^Listing' -e '^En train'
