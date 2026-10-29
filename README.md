# GSBLOLO - Infrastructure SISR

Ce dépôt présente mon infrastructure réalisée pour les ateliers professionnels.

| Atelier | Contenu | État |
| --- | --- | --- |
| AP 1 | À définir | À venir |
| [AP 2](AP%202/README.md) | À définir | À venir |
| [Structure du réseau](Structure%20du%20r%C3%A9seau/README.md) | Architecture réseau, Active Directory, DC secondaire et TrueNAS | En cours |

## Mon environnement Proxmox

Mon infrastructure utilise le réseau **10.2.121.0/24**, le **VLAN 800** et les VMID **801, 802 et 803**, dans le pool de ressources **Lolo** du nœud **pve**. Mon contrôleur de domaine utilise la VM **801 (AD-DC)** et l'adresse **10.2.121.2**. Ma DC secondaire utilise la VM **802 (DC-SECONDAIRE)** et l'adresse **10.2.121.3**. Mon serveur de stockage TrueNAS utilise la VM **803** et l'adresse **10.2.121.14**.

Je décris dans l'atelier [Structure du réseau](Structure%20du%20r%C3%A9seau/README.md) les étapes réalisées et les choix techniques de mon projet.
