# Architecture du réseau - AP 1

## Répartition et adressage

J'utilise les ressources qui me sont attribuées pour séparer les services de GSBLOLO.

| Élément | Mon infrastructure |
| --- | --- |
| Réseau IP | 10.2.121.0/24 |
| VLAN | 800 |
| VMID | 802 et suivants |
| Pont Proxmox | vmbr2 (carte Intel E1000, VLAN tag 800) |
| Contrôleur de domaine | 802, AD-DC, 10.2.121.2 |
| Poste client | Client2, 10.2.121.30 |
| Passerelle | 10.2.121.1 |
| DNS | 10.2.121.2 (DC) |

## Schéma

```
                 Proxmox VE (nœud pve) - pont vmbr2 - VLAN 800
                                   |
        +--------------------------+--------------------------+
        |                          |                          |
 Passerelle 10.2.121.1     AD-DC 10.2.121.2           Client2 10.2.121.30
                           AD DS + DNS                 membre de gsblolo.local
                           gsblolo.local
```

## Flux

1. Mon poste client utilise 10.2.121.2 pour résoudre gsblolo.local.
2. Il joint AD-DC pour l'authentification et les stratégies de groupe.
3. Les accès vers Internet passent par la passerelle 10.2.121.1.
