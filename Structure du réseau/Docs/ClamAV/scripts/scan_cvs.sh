#!/bin/bash
# =============================================================================
# scan_cvs.sh — Analyse antivirus des CV déposés via le serveur web
# Emplacement : /usr/local/bin/scan_cvs.sh   (chmod +x)
# Planification : crontab root -> */15 * * * * /usr/local/bin/scan_cvs.sh
#
# Chaque fichier de cv_incoming est analysé par ClamAV :
#   - code 0 (sain)      -> déplacé dans cv_safe
#   - code 1 (infecté)   -> déplacé dans cv_infected
#   - autre (erreur)     -> déplacé dans cv_infected par précaution
# Chaque résultat est journalisé dans /var/log/clamav/scan_cvs.log
#
# IMPORTANT : ne jamais placer ce script dans cv_incoming, sinon il serait
# lui-même analysé puis déplacé.
# =============================================================================

INCOMING="/var/www/data/cv_incoming"
SAFE="/var/www/data/cv_safe"
INFECTED="/var/www/data/cv_infected"
LOG="/var/log/clamav/scan_cvs.log"

mkdir -p "$SAFE" "$INFECTED"

for file in "$INCOMING"/*; do
    # Dossier vide : le motif "*" n'est pas développé, on ignore
    [ -e "$file" ] || continue

    result=$(clamscan --stdout "$file" 2>&1)
    ret=$?

    echo "$(date '+%F %T') - $result" >> "$LOG"

    case "$ret" in
        0) mv -- "$file" "$SAFE"/ ;;
        1) mv -- "$file" "$INFECTED"/ ;;
        *) mv -- "$file" "$INFECTED"/ ;;   # erreur d'analyse : on isole
    esac
done
