#!/bin/bash
# verif_clamav.sh - Contrôle complet de la VM ClamAV (VM 812, à lancer en root)
echo "== Services (état / démarrage auto)"; for s in clamav-daemon clamav-freshclam clamonacc prometheus-node-exporter clamav-exporter cron; do printf '%-26s %-9s %s\n' "$s" "$(systemctl is-active $s)" "$(systemctl is-enabled $s)"; done
echo "== Unité Debian clamav-clamonacc (inactive disabled attendu)"; echo "$(systemctl is-active clamav-clamonacc 2>/dev/null) $(systemctl is-enabled clamav-clamonacc 2>/dev/null)"
echo "== Timer du scan hebdo"; systemctl list-timers scan-home-hebdo.timer --no-pager | sed -n 2p
echo "== Ports"; ss -tlnp | grep -E ':(9100|9906|3310) ' | awk '{print $4, $6}'
echo "== Dossiers de quarantaine utilisés par les services"; grep -rhoE -- '--move=[^ ]+' /etc/systemd/system/*.service | sort | uniq -c
echo "== /var/quarantine doit être absent"; ls -ld /var/quarantine 2>&1 | head -1; ls -ld /var/quarantaine
echo "== Temps réel"; grep -E "^OnAccess(IncludePath|ExtraScanning|Prevention)" /etc/clamav/clamd.conf
echo "== clamonacc surveille"; grep "watching" /var/log/clamav/clamonacc.log | tail -2
echo "== clamd en TCP local"; grep -E "^TCP(Socket|Addr)" /etc/clamav/clamd.conf
echo "== Exclusion de la quarantaine ClamUI (1 attendu)"; grep -c "exclude-dir=.*clamui/quarantine" /etc/systemd/system/scan-home-hebdo.service
echo "== Crontab root"; crontab -l | grep -v '^#'
echo "== Script de métriques"; echo "dernier passage il y a $(( $(date +%s) - $(awk '/^clamav_metrics_last_run/ {print $2}' /var/lib/prometheus/node-exporter/clamav_scans.prom) )) s"
echo "== Dernière mise à jour des signatures"; grep -E "daily\.c[vl]d (updated|database is up-to-date)" /var/log/clamav/freshclam.log | tail -1
echo "== Heure"; timedatectl timesync-status | grep -E "Server|Leap|Offset"
echo "== Disque /"; df -h / | tail -1 | awk '{print $5" utilisé, "$4" libres"}'
echo "== Noyau et mises à jour en attente"; uname -r; apt list --upgradable 2>/dev/null | grep -vc -e '^Listing' -e '^En train'
