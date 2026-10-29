# AP 2 - GSBLOLO

## Objectif

J'ajoute à l'infrastructure de l'AP 1 un serveur de stockage **TrueNAS** et je le rattache au domaine **gsblolo.local**.

## Documentation

| Sujet | Description |
| --- | --- |
| [TrueNAS](Docs/TrueNAS/TrueNAS.md) | VM, installation de TrueNAS 25.10.1 et intégration au domaine |

## Avancement

- J'ai créé la VM **TrueNAS** (VMID 803) sur Proxmox, sur le même réseau que le contrôleur de domaine (vmbr2, VLAN 800).
- J'ai installé **TrueNAS Community Edition 25.10.1 (Goldeye)** et configuré le compte **truenas_admin**.
- Le serveur apparaît dans l'annuaire Active Directory sous le nom **TRUENAS**.
