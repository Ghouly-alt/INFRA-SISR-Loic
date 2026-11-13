# Sauvegarde et PRA - AP 2 GSBLOLO

> 🚧 **Cahier des charges.** Cette page décrit ce que je vais mettre en place. Les captures et les résultats des tests seront ajoutés au fur et à mesure.

## 1. Contexte et besoin

L'infrastructure de GSBLOLO compte un annuaire (AD-DC et DC-SECONDAIRE), un serveur de fichiers (TrueNAS, partages SMB par service), un antivirus (ClamAV) et une supervision (Prometheus, AP 1). **Aucune donnée n'est sauvegardée aujourd'hui.**

Les risques sont réels :

- le pool **Stockage** de TrueNAS repose sur **un seul disque**, sans redondance ;
- un utilisateur peut supprimer ou écraser un fichier par erreur ;
- un rançongiciel peut chiffrer les partages des services ;
- une erreur d'administration peut supprimer une OU ou des comptes ;
- une VM peut être perdue (disque corrompu, mauvaise manipulation).

**Objectif de l'AP 2 :** mettre en place une politique de sauvegarde, puis **prouver par des tests** que chaque service peut être restauré dans un délai défini.

## 2. Objectifs de reprise (RPO / RTO)

- **RPO** (perte de données maximale acceptée) : l'âge de la dernière sauvegarde utilisable.
- **RTO** (durée maximale d'interruption) : le temps pour remettre le service en marche.

| Service | Données | RPO visé | RTO visé |
| --- | --- | --- | --- |
| Annuaire (AD DS, DNS) | Comptes, groupes, OU, GPO | 24 h (0 en cas de panne d'un seul DC grâce à la réplication) | 15 min (objet supprimé), 1 h (DC à restaurer) |
| Fichiers des services | Partages SMB de `Stockage/Services` | 1 h en journée | 15 min (fichier), 30 min (partage entier) |
| Supervision | Configuration Prometheus et Grafana, tableaux de bord | 24 h | 2 h |
| ClamAV | Configuration, script de tri, services systemd | 24 h | 2 h |
| Métriques Prometheus | Historique des mesures | Non sauvegardé (accepté) | - |

## 3. Architecture de sauvegarde

J'applique au mieux la **règle 3-2-1** : 3 copies des données, sur 2 supports différents, dont 1 hors site.

```
                         TrueNAS (VM 803) - 10.2.121.14
   +---------------------------------------------------------------------+
   |  Pool Stockage (disque 32 Gio)        Pool Sauvegardes (nouveau)     |
   |  Stockage/Services/*  --snapshots-->  Sauvegardes/Services (réplica)  |
   |   (horaires + quotidiens)              Sauvegardes/AD     <- AD-DC     |
   |                                        Sauvegardes/Linux  <- VM Linux  |
   +---------------------------------------------------------------------+
        ^ SMB (utilisateurs)                 ^ SMB (compte svc-sauvegarde)
        |                                    |
   Postes clients              AD-DC (état du système, chaque soir)
                               SUPERVISION .15 et Client-Linux-Debian .12
                               (archives de configuration, chaque nuit)
                                             |
                                             v
                    Prometheus : alerte si une sauvegarde est en retard
```

| Copie | Emplacement | Contenu |
| --- | --- | --- |
| 1 (production) | Pool `Stockage`, AD-DC, VM Linux | Données en service |
| 2 | Snapshots ZFS du pool `Stockage` | Versions horaires et quotidiennes des fichiers |
| 3 | Pool `Sauvegardes` (second disque) | Réplica des fichiers, état du système AD, configurations Linux |

### Prérequis à valider avec le professeur

- Ajouter un **troisième disque virtuel** à la VM 803 sur `Raid5-VMs` (100 Gio conseillés, à adapter à l'espace libre).
- Savoir si j'ai le droit de lancer des **sauvegardes Proxmox (vzdump)** des VM de mon pool `Lolo` (étape facultative 7).

## 4. Réalisations prévues

### 4.1 Pool de sauvegarde sur TrueNAS

1. Ajouter le disque depuis le shell du nœud Proxmox, avec un numéro de série (sinon TrueNAS refuse le pool, comme pour le pool `Stockage`) :
   ```bash
   qm set 803 --scsi2 Raid5-VMs:100,iothread=1,serial=TRUENAS0003
   ```
2. Créer le pool **Sauvegardes** sur ce disque.
3. Créer les datasets `Sauvegardes/AD` et `Sauvegardes/Linux` (préréglage SMB) et `Sauvegardes/Services` (cible de réplication, sans partage).
4. Créer dans l'AD le compte de service **svc-sauvegarde** et le groupe **sauvegarde**. Seuls ce groupe et **Admins du domaine** ont des droits sur `Sauvegardes/AD` et `Sauvegardes/Linux`. Les utilisateurs des services n'y ont **aucun accès**.
5. Créer les partages SMB `sauvegarde-ad` et `sauvegarde-linux`.

### 4.2 Snapshots des partages des services

Dans **Data Protection > Periodic Snapshot Tasks**, sur `Stockage/Services` en **récursif** :

| Tâche | Fréquence | Conservation |
| --- | --- | --- |
| Horaire | Toutes les heures de 8 h à 19 h, du lundi au vendredi | 2 jours |
| Quotidienne | Tous les jours à 20 h | 14 jours |

Dans les options avancées de chaque partage SMB, j'active les **clichés instantanés (Shadow Copies)** : les utilisateurs retrouvent alors les snapshots dans l'onglet **Versions précédentes** de l'explorateur Windows et peuvent restaurer un fichier eux-mêmes.

**Intérêt contre les rançongiciels :** les snapshots ZFS sont en lecture seule et ne sont pas modifiables depuis un partage SMB. Un poste infecté peut chiffrer les fichiers du partage, mais pas leurs snapshots.

### 4.3 Réplication vers le pool Sauvegardes

Dans **Data Protection > Replication Tasks** : réplication **locale** de `Stockage/Services` vers `Sauvegardes/Services`, chaque soir après le snapshot quotidien, avec une conservation de 30 jours. Si le disque du pool `Stockage` est perdu, les données restent disponibles sur le second pool.

### 4.4 Sauvegarde de l'Active Directory

1. **Activer la corbeille AD** (opération irréversible, sans risque) :
   ```powershell
   Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'gsblolo.local'
   ```
2. **Installer la Sauvegarde Windows Server** sur AD-DC :
   ```powershell
   Install-WindowsFeature Windows-Server-Backup
   ```
3. **Planifier la sauvegarde de l'état du système** (AD, SYSVOL, DNS, registre) chaque soir à 21 h vers `\\10.2.121.14\sauvegarde-ad`, avec le compte `svc-sauvegarde` :
   ```powershell
   $policy = New-WBPolicy
   Add-WBSystemState -Policy $policy
   $cred   = Get-Credential 'GSBLOLO\svc-sauvegarde'
   $target = New-WBBackupTarget -NetworkPath '\\10.2.121.14\sauvegarde-ad' -Credential $cred
   Add-WBBackupTarget -Policy $policy -Target $target
   Set-WBSchedule -Policy $policy -Schedule 21:00
   Set-WBPolicy -Policy $policy
   ```
4. **Garder plusieurs versions :** sur un partage réseau, Windows ne conserve que la **dernière** sauvegarde et écrase la précédente. J'ajoute donc une tâche de snapshots quotidiens sur `Sauvegardes/AD` (conservation 7 jours) pour garder un historique.

Je sauvegarde AD-DC, qui porte les rôles FSMO. DC-SECONDAIRE est une réplique : il n'a pas besoin d'une sauvegarde séparée pour ce projet.

> Une sauvegarde d'un DC plus ancienne que la durée de vie des objets supprimés (180 jours par défaut) n'est plus utilisable.

### 4.5 Sauvegarde des configurations Linux

Sur **SUPERVISION** (10.2.121.15) et **Client-Linux-Debian** (10.2.121.12), un script archive chaque nuit les fichiers de configuration vers `\\10.2.121.14\sauvegarde-linux`.

| Machine | Fichiers sauvegardés |
| --- | --- |
| SUPERVISION | `/etc/prometheus/`, `/etc/default/prometheus`, `/etc/grafana/`, `/var/lib/grafana/grafana.db` (tableaux de bord) |
| Client-Linux-Debian | `/etc/clamav/`, `/usr/local/bin/scan_cvs.sh`, `/etc/systemd/system/clamonacc.service`, `/etc/systemd/system/scan-home-hebdo.*`, l'unité de clamav_exporter, `/etc/NetworkManager/system-connections/` (IP fixe) |

**Montage du partage** (paquet `cifs-utils`), dans `/etc/fstab` :

```
//10.2.121.14/sauvegarde-linux /mnt/sauvegarde-linux cifs credentials=/root/.smb-sauvegarde,vers=3.0,noauto,x-systemd.automount,file_mode=0600,dir_mode=0700 0 0
```

Le fichier `/root/.smb-sauvegarde` (droits `600`) contient `username=svc-sauvegarde`, `password=...` et `domain=GSBLOLO`. Le mot de passe n'apparaît jamais dans le script ni dans ce dépôt.

**Script** `/usr/local/bin/sauvegarde_config.sh` :

```bash
#!/bin/bash
# Archive les fichiers de configuration listés dans /etc/sauvegarde/liste.txt
# et publie la date de la dernière réussite pour Prometheus.
set -euo pipefail

MACHINE=$(hostname -s)
DATE=$(date +%Y-%m-%d_%H-%M)
DEST="/mnt/sauvegarde-linux/$MACHINE"
LISTE="/etc/sauvegarde/liste.txt"
CONSERVATION_JOURS=14
METRIQUE="/var/lib/prometheus/node-exporter/sauvegarde.prom"

mkdir -p "$DEST"
ARCHIVE="$DEST/config_$DATE.tar.gz"

tar -czf "$ARCHIVE" --files-from="$LISTE"
tar -tzf "$ARCHIVE" > /dev/null          # vérifie que l'archive est lisible

find "$DEST" -name 'config_*.tar.gz' -mtime +"$CONSERVATION_JOURS" -delete

# Écriture dans un fichier temporaire puis renommage, pour que node_exporter
# ne lise jamais un fichier à moitié écrit.
echo "sauvegarde_derniere_reussite_timestamp_seconds $(date +%s)" > "$METRIQUE.tmp"
mv "$METRIQUE.tmp" "$METRIQUE"
```

Avec `set -e`, le script s'arrête à la première erreur : la date de réussite n'est alors pas mise à jour et l'alerte de la section 4.6 se déclenche. Le script est lancé chaque nuit à 2 h par un service et un timer systemd, comme le scan hebdomadaire de ClamAV.

> Le dossier `/var/lib/prometheus/node-exporter` est celui du collecteur *textfile* du paquet Debian. Si node_exporter a été installé autrement, j'utilise le dossier passé à `--collector.textfile.directory`.

### 4.6 Supervision des sauvegardes (lien avec l'AP 1)

J'ajoute un fichier de règles dans Prometheus (`/etc/prometheus/regles_sauvegarde.yml`, déclaré dans `rule_files` de `prometheus.yml`) :

```yaml
groups:
  - name: sauvegardes
    rules:
      - alert: SauvegardeEnRetard
        expr: time() - sauvegarde_derniere_reussite_timestamp_seconds > 26 * 3600
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pas de sauvegarde réussie depuis plus de 26 h sur {{ $labels.instance }}"
```

Je valide le fichier avec `promtool check rules`, puis je vérifie l'alerte dans la page **Alerts** de Prometheus. Un panneau Grafana affiche l'âge de la dernière sauvegarde de chaque machine.

Pour l'AD, je vérifie chaque semaine dans l'Observateur d'événements (**Applications et services > Microsoft > Windows > Backup**) que la sauvegarde s'est bien terminée.

### 4.7 (Facultatif) Sauvegarde des VM avec Proxmox

Si mes droits le permettent, une sauvegarde **vzdump** hebdomadaire des VM 801, 802, 804 et 812 (mode snapshot, compression zstd) permet de restaurer une VM entière en quelques minutes. Sinon, je l'indique dans les limites.

## 5. Scénarios de PRA à tester

Chaque scénario est **joué pour de vrai**, chronométré et documenté avec des captures : situation de départ, panne provoquée, procédure suivie, durée réelle, comparaison avec le RTO visé.

| N° | Incident simulé | Procédure de reprise | RTO visé |
| --- | --- | --- | --- |
| S1 | Un administrateur supprime l'OU `Test-PRA` qui contient 3 comptes | Restauration depuis la corbeille AD | 15 min |
| S2 | Un utilisateur de la Comptabilité supprime un fichier important | **Versions précédentes** depuis le poste, sans intervention de la DSI | 5 min |
| S3 | Rançongiciel simulé : tous les fichiers du partage `Accueil` sont renommés en `.locked` et écrasés | Retour arrière (rollback) sur le dernier snapshot sain | 30 min |
| S4 | Panne de AD-DC (VM arrêtée) | DC-SECONDAIRE continue à authentifier et à résoudre les noms | 0 (automatique) |
| S5 | AD-DC corrompu, à restaurer | Restauration de l'état du système en mode DSRM | 1 h |
| S6 | Perte de la VM SUPERVISION | Réinstallation de Debian 12, puis restauration de l'archive de configuration | 2 h |
| S7 | Perte du disque du pool `Stockage` | Restauration des données depuis `Sauvegardes/Services` | 1 h |

### Points d'attention

- **S1 :** l'OU de test doit être créée **sans** la protection contre la suppression accidentelle, sinon elle ne peut pas être supprimée. On restaure d'abord l'OU, puis les comptes qu'elle contenait :
  ```powershell
  Get-ADObject -Filter 'Name -eq "Test-PRA"' -IncludeDeletedObjects | Restore-ADObject
  Get-ADObject -Filter 'isDeleted -eq $true -and LastKnownParent -like "*Test-PRA*"' -IncludeDeletedObjects | Restore-ADObject
  ```
- **S3 :** la simulation se fait uniquement sur un **jeu de fichiers de test** (un simple script PowerShell qui renomme et écrase les fichiers), jamais avec un vrai logiciel malveillant. Je rappelle aussi le rôle de ClamAV et de la segmentation dans la prévention.
- **S4 :** il faut d'abord ajouter **10.2.121.3** comme DNS secondaire sur les postes (étape prévue dans la doc du DC secondaire). Pour un test fiable, je me connecte avec un compte qui ne s'est jamais connecté sur ce poste (sinon Windows utilise les identifiants en cache), puis je vérifie que `echo %LOGONSERVER%` affiche `\\DC-SECONDAIRE`. Je vérifie aussi les rôles FSMO avec `netdom query fsmo` et j'explique quand il faudrait les saisir sur DC-SECONDAIRE (panne définitive de AD-DC).
- **S5 :** restauration **non autoritaire** : AD-DC revient à l'état de la sauvegarde, puis récupère par réplication les modifications plus récentes depuis DC-SECONDAIRE.
  ```powershell
  bcdedit /set safeboot dsrepair        # redémarrage en mode DSRM
  # après redémarrage, session avec le compte DSRM :
  net use \\10.2.121.14\sauvegarde-ad /user:GSBLOLO\svc-sauvegarde
  wbadmin get versions -backupTarget:\\10.2.121.14\sauvegarde-ad
  wbadmin start systemstaterecovery -version:<version> -backupTarget:\\10.2.121.14\sauvegarde-ad
  bcdedit /deletevalue safeboot         # retour au démarrage normal
  ```
  Je vérifie ensuite avec `repadmin /replsummary` et `dcdiag`.

## 6. Cahier de recette

| Test | Résultat attendu | Résultat obtenu |
| --- | --- | --- |
| Snapshot horaire présent dans **Data Protection** | Un snapshot par heure entre 8 h et 19 h | ⏳ |
| Onglet **Versions précédentes** sur un fichier d'un partage | Les snapshots apparaissent | ⏳ |
| Utilisateur de l'Accueil qui ouvre `\\10.2.121.14\sauvegarde-ad` | Accès refusé | ⏳ |
| Réplication vers `Sauvegardes/Services` | Tâche en état **Finished**, données identiques | ⏳ |
| Sauvegarde de l'état du système de AD-DC | Événement de réussite dans le journal Backup | ⏳ |
| Script `sauvegarde_config.sh` | Archive créée et lisible, métrique mise à jour | ⏳ |
| Arrêt du montage SMB, puis lancement du script | Le script échoue, l'alerte **SauvegardeEnRetard** passe en *firing* après 26 h (ou avec un seuil réduit pour le test) | ⏳ |
| Scénarios S1 à S7 | Service rétabli dans le RTO visé | ⏳ |

## 7. Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Disque supplémentaire, pool `Sauvegardes`, compte `svc-sauvegarde` | ⏳ |
| 2 | Snapshots de `Stockage/Services` et Versions précédentes | ⏳ |
| 3 | Réplication vers `Sauvegardes/Services` | ⏳ |
| 4 | Corbeille AD et sauvegarde de l'état du système de AD-DC | ⏳ |
| 5 | Sauvegarde des configurations Linux | ⏳ |
| 6 | Alertes Prometheus et panneau Grafana | ⏳ |
| 7 | (Facultatif) Sauvegardes vzdump | ⏳ |
| 8 | Scénarios S1 à S7 joués et chronométrés | ⏳ |

## 8. Limites et améliorations

- **Pas de vraie séparation physique :** le pool `Sauvegardes` est un disque virtuel sur le même stockage `Raid5-VMs` et le même hôte Proxmox que les données. Une panne de l'hôte ferait tout perdre. En entreprise, la copie 3 serait sur un autre serveur, dans un autre bâtiment ou dans le cloud.
- **Pas de copie hors site :** la règle 3-2-1 n'est donc pas complètement respectée. Une piste serait une réplication ZFS par SSH vers un autre TrueNAS, ou une tâche **Cloud Sync** vers un stockage objet, avec chiffrement.
- **Pool `Stockage` sans redondance :** un miroir de deux disques éviterait de devoir restaurer dès qu'un disque tombe en panne.
- **Pas d'immuabilité hors TrueNAS :** un administrateur TrueNAS compromis pourrait supprimer les snapshots. Un compte dédié avec MFA et des sauvegardes immuables réduiraient ce risque.

## 9. Compétences mobilisées

| Bloc | Compétence |
| --- | --- |
| Bloc 1 | Gérer le patrimoine informatique |
| Bloc 1 | Mettre à disposition des utilisateurs un service informatique |
| Bloc 2 SISR | Concevoir une solution d'infrastructure réseau |
| Bloc 2 SISR | Installer, tester et déployer une solution d'infrastructure réseau |
| Bloc 2 SISR | Exploiter, dépanner et superviser une solution d'infrastructure réseau |
| Bloc 3 | Garantir la disponibilité, l'intégrité et la confidentialité des services informatiques et des données de l'organisation face à des cyberattaques |
