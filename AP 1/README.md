# AP 1 - GSBLOLO

## Contexte

Mon projet consiste à mettre en place l'annuaire Active Directory de l'organisation **GSB** afin de centraliser l'authentification des utilisateurs et la gestion des postes. Les principaux services concernés sont : Accueil, Communication, Comptabilité, Développement, DSI, Labo-recherche, Réseaux & Systèmes et RH.

## Objectif

Je mets en place un contrôleur de domaine (AD DS + DNS), l'arborescence des OU, les groupes et les comptes utilisateurs, puis je joins un poste client Windows au domaine, le tout sur **Proxmox VE**.

## Documentation

| Sujet | Description |
| --- | --- |
| [Architecture du réseau](Architecture%20du%20r%C3%A9seau/Architecture-du-reseau.md) | VLAN, adressage et flux |
| [Active Directory](Docs/Active%20Directory/Active-Directory.md) | VM, domaine, OU, groupes, comptes et jonction d'un poste |
| [Contrôleur de domaine secondaire](Docs/DC%20secondaire/DC-secondaire.md) | VM DC-SECONDAIRE et liaison avec le DC principal |
| [TrueNAS](Docs/TrueNAS/TrueNAS.md) | VM, installation de TrueNAS 25.10.1 et intégration au domaine |

## Avancement

- J'ai créé 2 VM sur Proxmox : le contrôleur de domaine **AD-DC** (Windows Server 2022) et le poste **Client2** (Windows Entreprise).
- J'ai configuré les rôles AD DS et DNS et le domaine **gsblolo.local** (NetBIOS **GSBLOLO**).
- J'ai créé les OU, 8 groupes de sécurité et les comptes utilisateurs (import PowerShell depuis un CSV).
- J'ai joint le poste client au domaine et ouvert une session avec le compte **GSBLOLO\X.turnbull**.
- J'ai créé la VM **TrueNAS** (VMID 803), installé **TrueNAS Community Edition 25.10.1** et vérifié qu'elle apparaît dans l'annuaire sous le nom **TRUENAS**.
- J'ai créé la VM **DC-SECONDAIRE** (VMID 802, 10.2.121.3), destinée à devenir un second contrôleur du domaine **GSBLOLO.local**.
- La suite du projet porte sur l'AP 2.
