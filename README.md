# GSBLOLO - Infrastructure SISR

Ce dépôt présente mon infrastructure réalisée pour les ateliers professionnels.

| Atelier | Contenu | État |
| --- | --- | --- |
| [AP 1](AP%201/README.md) | Réseau, virtualisation et Active Directory | Terminé |
| [AP 2](AP%202/README.md) | À définir | À venir |

## Mon environnement Proxmox

Mon infrastructure utilise le réseau **10.2.121.0/24**, le **VLAN 800** et les VMID à partir de **802**, dans le pool de ressources **Lolo** du nœud **pve**. Mon contrôleur de domaine utilise la VM **802 (AD-DC)** et l'adresse **10.2.121.2**.

Je décris dans l'[AP 1](AP%201/README.md) les étapes réalisées et les choix techniques de mon projet.
