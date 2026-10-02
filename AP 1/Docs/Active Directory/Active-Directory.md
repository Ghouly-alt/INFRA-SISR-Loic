# Active Directory - AP 1 GSBLOLO

Je présente ici la mise en place de mon contrôleur de domaine puis la jonction d'un poste client, avec mes propres captures d'écran.

## 1. Créer la machine virtuelle

J'ai créé une VM sur Proxmox VE (nœud **pve**, pool **Lolo**) avec le **VMID 801** et le nom **AD-DC**.

![Onglet General](images/01-vm-general.png)

L'ISO `win-server.iso` est montée depuis le stockage `local`, type d'OS Microsoft Windows 11/2022/2025.

![Onglet OS](images/02-vm-os.png)

Machine **q35**, BIOS **OVMF (UEFI)** avec disque EFI et **TPM v2.0** sur le stockage `Raid5-VMs`, contrôleur VirtIO SCSI single.

![Onglet System](images/03-vm-system.png)

Disque **IDE de 64 Gio** sur `Raid5-VMs`.

![Onglet Disks](images/04-vm-disque.png)

**4 vCPU** (2 sockets × 2 cœurs), type `x86-64-v2-AES`, et **4 Gio de RAM**.

![Onglet CPU](images/05-vm-cpu.png)

![Onglet Memory](images/06-vm-memoire.png)

La carte réseau **Intel E1000** est reliée au pont **vmbr2** avec le **VLAN tag 800**.

![Onglet Network](images/07-vm-reseau.png)

J'y ai installé **Windows Server 2022 Standard Evaluation (expérience de bureau)** en français, puis j'ai défini le mot de passe du compte Administrateur.

![Langue](images/08-install-langue.png)

![Choix de l'édition](images/09-install-edition.png)

![Licence](images/10-install-licence.png)

![Installation](images/11-install-copie.png)

![Mot de passe administrateur](images/12-mdp-admin.png)

## 2. Configurer le nom et le réseau

J'ai configuré l'adresse statique **10.2.121.2/24** (masque 255.255.255.0) sur la carte Ethernet. Son DNS préféré est **10.2.121.2** (lui-même), DNS auxiliaire 8.8.8.8, et sa passerelle est **10.2.121.1**.

![Centre Réseau et partage](images/37-dc-reseau-partage.png)

![Propriétés de la carte](images/38-dc-carte.png)

![Configuration IP du serveur](images/13-ip-dc.png)

## 3. Installer AD DS et DNS

Depuis le Gestionnaire de serveur : **Gérer > Ajouter des rôles et fonctionnalités**, installation basée sur un rôle, sélection du serveur local.

![Ajout de rôles](images/14-ajout-roles.png)

![Type d'installation](images/15-type-install.png)

![Serveur de destination](images/16-serveur-destination.png)

J'ai coché les rôles **Services AD DS** et **Serveur DNS**, puis lancé l'installation.

![Rôles AD DS et DNS](images/17-roles-ad-dns.png)

![Confirmation](images/18-confirmation.png)

J'ai ensuite cliqué sur **Promouvoir ce serveur en contrôleur de domaine** pour créer une nouvelle forêt **gsblolo.local**.

![Promotion](images/19-promotion.png)

Niveau fonctionnel de forêt et de domaine **Windows Server 2016**, avec serveur DNS et catalogue global, et mot de passe DSRM.

![Options du contrôleur](images/20-options-dc.png)

L'avertissement sur la délégation DNS est normal (pas de zone parente).

![Options DNS](images/21-options-dns.png)

Le nom NetBIOS est **GSBLOLO**. Les chemins NTDS et SYSVOL sont laissés par défaut.

![NetBIOS](images/22-netbios.png)

![Chemins d'accès](images/23-chemins.png)

Toutes les vérifications sont validées, le serveur redémarre après l'installation.

![Vérification](images/24-verification.png)

## 4. Créer les OU, groupes et comptes

J'ouvre **Outils > Utilisateurs et ordinateurs Active Directory**.

![Outils](images/25-outils-aduc.png)

Sous **gsblolo.local**, j'ai créé l'OU **Services** qui contient trois OU : **Utilisateurs**, **Ordinateur** et **Groupes**.

![Arborescence des OU](images/26-ou.png)

J'ai créé 8 groupes de sécurité, un par service : Accueil, Communication, Comptabilité, Développement, DSI, Labo-recherche, Réseaux & Systèmes et RH.

![Groupes de sécurité](images/28-groupes.png)

Les comptes utilisateurs ont été créés avec le [script d'import](Import-Utilisateurs.ps1) à partir d'un fichier CSV (colonnes `Prenom`, `Nom`, `Fonction`). L'identifiant suit la forme `initiale.nom` (ex. `X.Turnbull`), l'UPN est `identifiant@gsblolo.local` et l'utilisateur doit changer son mot de passe à la première connexion.

![Comptes utilisateurs](images/27-utilisateurs.png)

## 5. Créer et joindre le poste client

J'ai créé une seconde VM **Client2** (**VMID 802**) dans le même pool, avec la même configuration matérielle (UEFI + TPM, 4 vCPU, disque IDE de 60 Gio, vmbr2 / VLAN 800) et l'ISO Windows Entreprise.

![Client - General](images/29-client-general.png)

![Client - OS](images/30-client-os.png)

![Client - System](images/31-client-system.png)

![Client - Disque](images/32-client-disque.png)

![Client - CPU](images/33-client-cpu.png)

![Client - Réseau](images/34-client-reseau.png)

Pendant l'installation, j'ai choisi **Rejoindre un domaine Active Directory local** (création d'un compte local, jonction ensuite).

![Démarrage](images/35-client-oobe.png)

![Mode de connexion](images/36-client-ad-local.png)

Adresse du client : **10.2.121.30/24**, passerelle 10.2.121.1, DNS **10.2.121.2** (le DC, indispensable pour trouver le domaine).

![IP du client](images/39-client-ip.png)

Jonction : **Paramètres > Comptes > Accès Professionnel ou Scolaire > Connecter > Joindre un domaine**, domaine **GSBLOLO**, authentification avec un compte administrateur du domaine.

![Paramètres](images/40-client-parametres.png)

![Accès professionnel](images/41-client-acces-pro.png)

![Nom du domaine](images/42-client-domaine.png)

![Authentification](images/43-client-auth.png)

J'ai ajouté l'utilisateur du domaine **X.turnbull** comme utilisateur standard, puis redémarré.

![Ajout du compte](images/44-client-compte.png)

![Redémarrage](images/45-client-redemarrer.png)

## 6. Vérifier le fonctionnement

Après redémarrage, la session **GSBLOLO\X.turnbull** s'ouvre sur le poste et Windows demande de définir un nouveau mot de passe : le poste est bien membre du domaine et l'authentification passe par le contrôleur AD-DC.

![Connexion avec un compte du domaine](images/46-client-connexion.png)
