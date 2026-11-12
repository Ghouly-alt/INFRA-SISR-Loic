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
| 5 | Script de métriques : scans, quarantaine, tri des CV, ClamUI | ⏳ |
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

## Problèmes rencontrés (à détailler dans la doc finale)

- Installeur Debian : l'IP se règle après l'annulation de la configuration DHCP.
- `Booting from Hard Disk...` bloqué : GRUB non installé, réparé avec le mode de secours de l'ISO.
- PC Windows sans route vers 10.2.121.0/24 : travail depuis la VM ClamAV (navigateur + SSH).
- VM ClamAV en DHCP : son IP est passée de `.10` à `.12`, donc `Destination Host Unreachable`. Elle a été mise en IP fixe avec `nmcli`.
- `curl` absent sur SUPERVISION, et cible ClamAV oubliée dans `prometheus.yml`.
- `clamav_memory_used_bytes` sans données (statistiques mémoire de clamd non remontées).
