# Architecture du réseau - AP 1

## Répartition et adressage

J'utilise les ressources qui me sont attribuées pour séparer les services de GSBLOLO.

| Élément | Mon infrastructure |
| --- | --- |
| Réseau IP | 10.2.121.0/24 |
| VLAN | 800 |
| VMID | 801 (AD-DC), 802 (Client2) |
| Pont Proxmox | vmbr2 (carte Intel E1000, VLAN tag 800) |
| Contrôleur de domaine | 801, AD-DC, 10.2.121.2 |
| Poste client | 802, Client2, 10.2.121.30 |
| Passerelle | 10.2.121.1 |
| DNS | 10.2.121.2 (DC) |

## Postes clients par service

Chaque service dispose d'un poste client. Les adresses commencent à 10.2.121.20 et augmentent de 10 en 10. Tous les postes utilisent le masque 255.255.255.0, la passerelle 10.2.121.1 et le DNS 10.2.121.2.

| Service | Poste | Adresse IP |
| --- | --- | --- |
| Accueil | PC-ACCUEIL | 10.2.121.20 |
| Communication | PC-COMMUNICATION | 10.2.121.30 |
| Comptabilité | PC-COMPTABILITE | 10.2.121.40 |
| Développement | PC-DEVELOPPEMENT | 10.2.121.50 |
| DSI | PC-DSI | 10.2.121.60 |
| Labo-recherche | PC-LABO | 10.2.121.70 |
| Réseaux & Systèmes | PC-RESEAUX | 10.2.121.80 |
| RH | PC-RH | 10.2.121.90 |

Le poste Client2 (10.2.121.30), déjà joint au domaine, occupe l'adresse du service Communication.

## Schéma

```
                     Proxmox VE (nœud pve) - pont vmbr2 - VLAN 800
                                         |
     +-------------------+---------------+-----------------------------+
     |                   |                                             |
 Passerelle         AD-DC 10.2.121.2                         Postes clients (gsblolo.local)
 10.2.121.1         AD DS + DNS                              10.2.121.20 Accueil
                    gsblolo.local                            10.2.121.30 Communication
                                                             10.2.121.40 Comptabilité
                                                             10.2.121.50 Développement
                                                             10.2.121.60 DSI
                                                             10.2.121.70 Labo-recherche
                                                             10.2.121.80 Réseaux & Systèmes
                                                             10.2.121.90 RH
```

## Flux

1. Les postes clients utilisent 10.2.121.2 pour résoudre gsblolo.local.
2. Ils joignent AD-DC pour l'authentification et les stratégies de groupe.
3. Les accès vers Internet passent par la passerelle 10.2.121.1.
