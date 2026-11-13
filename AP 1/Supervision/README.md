# Supervision Prometheus / Grafana - AP 1 GSBLOLO

> 🚧 **Documentation en cours de rédaction.** Cette page résume l'avancement. La documentation détaillée sera rédigée à la fin du projet, à partir des captures du dossier [`images/`](images/).

Je mets en place une supervision de mon infrastructure avec **Prometheus** (collecte des métriques) et **Grafana** (tableaux de bord). Le premier objectif est de superviser l'antivirus **ClamAV** et son interface **ClamUI**.

## Machines

| VM | Nom | IP | Rôle |
| --- | --- | --- | --- |
| 804 | SUPERVISION | 10.2.121.15 (fixe) | Prometheus, puis Grafana |
| 812 | Client-Linux-Debian | 10.2.121.12 (fixe) | ClamAV, ClamUI, node_exporter, clamav_exporter |

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | VM SUPERVISION : Debian 12, IP fixe, SSH | ✅ |
| 2 | Prometheus 2.42 (paquet Debian) et node_exporter local | ✅ |
| 3 | node_exporter sur la VM ClamAV, passage de la VM ClamAV en IP fixe | ✅ |
| 4 | clamav_exporter 2.1.13 (clamd en TCP sur 127.0.0.1:3310) | ✅ |
| 5 | Script de métriques : scans, quarantaine, tri des CV, ClamUI | ✅ |
| 6 | Grafana relié à Prometheus | ⏳ |
| 7 | Authentification Grafana via l'Active Directory (LDAP) | ⏳ |
| 8 | Tableau de bord ClamAV et alertes | ⏳ |

## Cibles Prometheus actuelles

| Job | Cible | Machine |
| --- | --- | --- |
| prometheus | localhost:9090 | supervision |
| node | localhost:9100 | supervision |
| node | 10.2.121.12:9100 | clamav |
| clamav | 10.2.121.12:9906 | clamav |

## Métriques ajoutées à l'étape 5

Le script [`scripts/clamav_metrics.sh`](scripts/clamav_metrics.sh) (installé dans `/usr/local/bin/` sur la VM ClamAV) tourne toutes les 5 minutes par la crontab de root. Il écrit `/var/lib/prometheus/node-exporter/clamav_scans.prom`, lu par le collecteur textfile de node_exporter : les métriques remontent donc par le job `node` (port 9100), sans modifier `prometheus.yml`.

| Source | Métriques |
| --- | --- |
| Quarantaine `/var/quarantaine` | `clamav_quarantine_files`, `clamav_quarantine_bytes` |
| Tri des CV (`scan_cvs.sh`) | `clamav_cv_files{dossier}`, `clamav_cv_scans_total`, `clamav_cv_infected_total` |
| Temps réel (`clamonacc.log`) | `clamav_onaccess_detections_total` |
| Scan hebdo de `/home` | `clamav_home_scan_last_timestamp_seconds`, `clamav_home_scan_scanned_files`, `clamav_home_scan_infected_files` |
| Services systemd | `clamav_service_active{service}` (clamav-daemon, clamonacc, clamav-freshclam) |
| ClamUI (Flatpak de `thibaut`) | `clamui_scans_total{status}`, `clamui_scanned_files_total`, `clamui_infected_files_total`, `clamui_last_scan_timestamp_seconds`, `clamui_last_scan_infected_files`, `clamui_quarantine_files{state}`, `clamui_quarantine_bytes` |
| Le script lui-même | `clamav_metrics_last_run_timestamp_seconds` (l'âge doit rester sous 300 s) |

Données ClamUI lues dans `/home/thibaut/.var/app/io.github.linx_systems.ClamUI/data/clamui/` : un JSON par analyse dans `logs/` (heures en UTC) et la base SQLite `quarantine.db` (ouverte en lecture seule).

Test de bout en bout (captures 73 à 79) : une analyse ClamUI de `~/Téléchargements` trouve 2 menaces mises en quarantaine ; après le passage du cron, Prometheus affiche `clamui_scans_total{status="infected"}` = 2, `clamui_quarantine_files{state="active"}` = 2 et `clamui_infected_files_total` = 3.

## Problèmes rencontrés (à détailler dans la doc finale)

- Installeur Debian : l'IP se règle après l'annulation de la configuration DHCP.
- `Booting from Hard Disk...` bloqué : GRUB non installé, réparé avec le mode de secours de l'ISO.
- PC Windows sans route vers 10.2.121.0/24 : travail depuis la VM ClamAV (navigateur + SSH).
- VM ClamAV en DHCP : son IP est passée de `.10` à `.12`, donc `Destination Host Unreachable`. Elle a été mise en IP fixe avec `nmcli`.
- `curl` absent sur SUPERVISION, et cible ClamAV oubliée dans `prometheus.yml`.
- `clamav_memory_used_bytes` sans données (statistiques mémoire de clamd non remontées).
- `clamav-freshclam` arrêté **et désactivé** (`disabled`) : plus aucune mise à jour des signatures depuis le 12/11. Détecté par la métrique `clamav_service_active`, corrigé avec `systemctl enable --now clamav-freshclam`.
- `clamav_quarantine_bytes` à 4096 avec une quarantaine vide : `du` comptait la taille du dossier lui-même. Remplacé par la somme des tailles des fichiers (`find -printf '%s'`).
- Un fichier EICAR est resté dans `/home/thibaut/Téléchargements` sans être bloqué : clamonacc surveille `/home/flo/Téléchargements` (à vérifier avec `grep OnAccessIncludePath /etc/clamav/clamd.conf`).
