#!/bin/bash
# clamav_metrics.sh - Métriques ClamAV pour Prometheus (collecteur textfile de node_exporter)
# Emplacement : /usr/local/bin/clamav_metrics.sh   (chmod +x)
# Planification : crontab root -> */5 * * * * /usr/local/bin/clamav_metrics.sh

OUT="/var/lib/prometheus/node-exporter/clamav_scans.prom"
TMP="$OUT.$$"                      # fichier temporaire, renommé à la fin
QUAR="/var/quarantaine"
CV="/var/www/data"
LOGDIR="/var/log/clamav"

# Compte les lignes d'un fichier qui correspondent à un motif (0 si absent)
compte() { local n; n=$(grep -cE "$1" "$2" 2>/dev/null); echo "${n:-0}"; }
# Compte les fichiers d'un dossier (sans sous-dossiers)
nb_fichiers() { find "$1" -maxdepth 1 -type f 2>/dev/null | wc -l; }

{
echo "# HELP clamav_quarantine_files Nombre de fichiers en quarantaine."
echo "# TYPE clamav_quarantine_files gauge"
echo "clamav_quarantine_files $(nb_fichiers "$QUAR")"

echo "# HELP clamav_quarantine_bytes Taille totale de la quarantaine en octets."
echo "# TYPE clamav_quarantine_bytes gauge"
echo "clamav_quarantine_bytes $(find "$QUAR" -maxdepth 1 -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {print s+0}')"

echo "# HELP clamav_cv_files Nombre de CV dans chaque dossier de tri."
echo "# TYPE clamav_cv_files gauge"
for d in incoming safe infected; do
    echo "clamav_cv_files{dossier=\"$d\"} $(nb_fichiers "$CV/cv_$d")"
done

echo "# HELP clamav_cv_scans_total CV analysés par scan_cvs.sh (depuis le début du journal)."
echo "# TYPE clamav_cv_scans_total counter"
echo "clamav_cv_scans_total $(compte '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} - ' "$LOGDIR/scan_cvs.log")"

echo "# HELP clamav_cv_infected_total CV détectés comme infectés par scan_cvs.sh."
echo "# TYPE clamav_cv_infected_total counter"
echo "clamav_cv_infected_total $(compte ' FOUND$' "$LOGDIR/scan_cvs.log")"

echo "# HELP clamav_onaccess_detections_total Détections de l'analyse en temps réel (clamonacc)."
echo "# TYPE clamav_onaccess_detections_total counter"
echo "clamav_onaccess_detections_total $(compte ' FOUND' "$LOGDIR/clamonacc.log")"

HEBDO="$LOGDIR/scan-home-hebdo.log"
echo "# HELP clamav_home_scan_last_timestamp_seconds Date du dernier scan hebdo de /home (epoch)."
echo "# TYPE clamav_home_scan_last_timestamp_seconds gauge"
echo "clamav_home_scan_last_timestamp_seconds $(stat -c %Y "$HEBDO" 2>/dev/null || echo 0)"

echo "# HELP clamav_home_scan_scanned_files Fichiers analysés lors du dernier scan hebdo."
echo "# TYPE clamav_home_scan_scanned_files gauge"
n=$(grep '^Scanned files:' "$HEBDO" 2>/dev/null | tail -1 | awk '{print $3}')
echo "clamav_home_scan_scanned_files ${n:-0}"

echo "# HELP clamav_home_scan_infected_files Fichiers infectés lors du dernier scan hebdo."
echo "# TYPE clamav_home_scan_infected_files gauge"
n=$(grep '^Infected files:' "$HEBDO" 2>/dev/null | tail -1 | awk '{print $3}')
echo "clamav_home_scan_infected_files ${n:-0}"

echo "# HELP clamav_service_active 1 si le service systemd est actif, 0 sinon."
echo "# TYPE clamav_service_active gauge"
for s in clamav-daemon clamonacc clamav-freshclam; do
    if systemctl is-active --quiet "$s"; then v=1; else v=0; fi
    echo "clamav_service_active{service=\"$s\"} $v"
done

echo "# HELP clamav_metrics_last_run_timestamp_seconds Dernière exécution de ce script (epoch)."
echo "# TYPE clamav_metrics_last_run_timestamp_seconds gauge"
echo "clamav_metrics_last_run_timestamp_seconds $(date +%s)"
# --- ClamUI (Flatpak de thibaut) : historique des analyses et quarantaine ---
CLAMUI="/home/thibaut/.var/app/io.github.linx_systems.ClamUI/data/clamui"
python3 - "$CLAMUI" <<'PY'
import json, re, sqlite3, sys
from datetime import datetime
from pathlib import Path

base = Path(sys.argv[1])

def epoch(ts):
    # "2026-11-12T13:06:14.761426132+00:00" : on retire les fractions de seconde
    return int(datetime.fromisoformat(re.sub(r"\.\d+", "", ts)).timestamp())

# Historique : un fichier JSON par analyse dans logs/ (sauf log_index.json)
scans = []
for f in (base / "logs").glob("*.json"):
    if f.name == "log_index.json":
        continue
    try:
        d = json.loads(f.read_text())
    except (OSError, ValueError):
        continue
    if d.get("type") == "scan":
        scans.append(d)

statuts = {"clean": 0, "infected": 0}   # toujours présents, même à 0
for s in scans:
    st = re.sub(r"[^a-z_]", "_", str(s.get("status", "inconnu")).lower())
    statuts[st] = statuts.get(st, 0) + 1

print("# HELP clamui_scans_total Analyses lancées depuis ClamUI, par résultat.")
print("# TYPE clamui_scans_total counter")
for st, n in sorted(statuts.items()):
    print(f'clamui_scans_total{{status="{st}"}} {n}')

print("# HELP clamui_scanned_files_total Fichiers analysés par ClamUI (toutes analyses).")
print("# TYPE clamui_scanned_files_total counter")
print(f"clamui_scanned_files_total {sum(s.get('scanned_files') or 0 for s in scans)}")

print("# HELP clamui_infected_files_total Menaces trouvées par ClamUI (toutes analyses).")
print("# TYPE clamui_infected_files_total counter")
print(f"clamui_infected_files_total {sum(s.get('infected_count') or 0 for s in scans)}")

derniere = max(scans, key=lambda s: s["timestamp"], default=None)
print("# HELP clamui_last_scan_timestamp_seconds Date de la dernière analyse ClamUI (epoch, 0 si aucune).")
print("# TYPE clamui_last_scan_timestamp_seconds gauge")
print(f"clamui_last_scan_timestamp_seconds {epoch(derniere['timestamp']) if derniere else 0}")

print("# HELP clamui_last_scan_infected_files Menaces trouvées lors de la dernière analyse ClamUI.")
print("# TYPE clamui_last_scan_infected_files gauge")
print(f"clamui_last_scan_infected_files {(derniere or {}).get('infected_count') or 0}")

# Quarantaine : base SQLite ouverte en lecture seule
etats = {"active": 0, "restored": 0, "deleted": 0}
taille = 0
try:
    c = sqlite3.connect(f"file:{base / 'quarantine.db'}?mode=ro", uri=True)
    for etat, n, octets in c.execute(
            "SELECT state, COUNT(*), COALESCE(SUM(file_size), 0) FROM quarantine GROUP BY state"):
        etats[etat] = n
        if etat == "active":
            taille = octets
    c.close()
except sqlite3.Error:
    pass

print("# HELP clamui_quarantine_files Fichiers de la quarantaine ClamUI, par état.")
print("# TYPE clamui_quarantine_files gauge")
for etat, n in etats.items():
    print(f'clamui_quarantine_files{{state="{etat}"}} {n}')

print("# HELP clamui_quarantine_bytes Taille des fichiers actuellement en quarantaine ClamUI.")
print("# TYPE clamui_quarantine_bytes gauge")
print(f"clamui_quarantine_bytes {taille}")
PY
} > "$TMP"

# Renommage atomique : node_exporter ne lit jamais un fichier à moitié écrit
chmod 644 "$TMP"
mv "$TMP" "$OUT"
