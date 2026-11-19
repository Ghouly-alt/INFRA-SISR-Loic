# =============================================================================
# ad_users_metrics.ps1 - Métriques des comptes Active Directory pour Prometheus
# Emplacement  : C:\Scripts\ad_users_metrics.ps1  (sur AD-DC, droits : Administrateurs + SYSTEM)
# Planification: tâche planifiée « Prometheus - utilisateurs AD », SYSTEM, toutes les 5 min
# Sortie       : C:\Program Files\windows_exporter\textfile_inputs\ad_users.prom
#                (lu par le collecteur textfile de windows_exporter, port 9182)
#
# Règles du format (doc windows_exporter) : fins de ligne LF, saut de ligne final,
# écriture dans un .tmp puis renommage (le collecteur ne lit que les .prom).
# Encodage UTF-8 SANS BOM, pour les accents dans les noms.
# En cas d'erreur, l'ancien fichier est conservé : ad_metrics_last_run vieillit
# et le tableau de bord / les alertes le voient.
# =============================================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$dossier = 'C:\Program Files\windows_exporter\textfile_inputs'
$sortie  = Join-Path $dossier 'ad_users.prom'
$tmp     = "$sortie.tmp"
$debut   = Get-Date

# Échappe une valeur de label Prometheus : \  "  et retours à la ligne
function Esc([string]$v) { ($v -replace '\\', '\\' -replace '"', '\"') -replace "`r?`n", ' ' }

# DateTime -> secondes depuis 1970 (0 si vide)
function Ts($d) { if ($d) { ([DateTimeOffset]$d).ToUnixTimeSeconds() } else { 0 } }

# "CN=Bodet Loic,OU=Utilisateurs,OU=Services,DC=gsblolo,DC=local" -> "Services/Utilisateurs"
function Conteneur([string]$dn) {
    $parent = ($dn -split '(?<!\\),', 2)[1]
    $parts  = @($parent -split '(?<!\\),' | Where-Object { $_ -notmatch '^DC=' } | ForEach-Object { $_.Substring(3) })
    [array]::Reverse($parts)
    $parts -join '/'
}

$lignes = New-Object System.Collections.Generic.List[string]
function Metrique([string]$nom, [string]$type, [string]$aide) {
    $lignes.Add("# HELP $nom $aide")
    $lignes.Add("# TYPE $nom $type")
}

# --- Dernière connexion réelle : lastLogon n'est pas répliqué, on prend le maximum de tous les DC
$dernierLogon = @{}
$dcErreurs = 0
$dcs = (Get-ADDomainController -Filter *).HostName
foreach ($dc in $dcs) {
    try {
        Get-ADUser -Filter * -Server $dc -Properties lastLogon | ForEach-Object {
            $v = [int64]$_.lastLogon
            if ($v -gt [int64]$dernierLogon[$_.SamAccountName]) { $dernierLogon[$_.SamAccountName] = $v }
        }
    } catch { $dcErreurs++ }
}

# --- Comptes utilisateurs du domaine
$proprietes = 'DisplayName', 'LockedOut', 'PasswordLastSet', 'PasswordNeverExpires', 'PasswordExpired', 'whenCreated', 'memberOf'
$users = Get-ADUser -Filter * -Properties $proprietes | Sort-Object SamAccountName

$def = [ordered]@{
    'ad_user_enabled'                             = 'gauge|1 si le compte est activé, 0 s''il est désactivé.'
    'ad_user_locked_out'                          = 'gauge|1 si le compte est verrouillé (trop de mauvais mots de passe).'
    'ad_user_password_expired'                    = 'gauge|1 si le mot de passe est expiré.'
    'ad_user_password_never_expires'              = 'gauge|1 si le mot de passe n''expire jamais.'
    'ad_user_password_last_set_timestamp_seconds' = 'gauge|Date du dernier changement de mot de passe (epoch, 0 si jamais).'
    'ad_user_last_logon_timestamp_seconds'        = 'gauge|Dernière connexion, maximum de tous les DC (epoch, 0 si jamais).'
    'ad_user_created_timestamp_seconds'           = 'gauge|Date de création du compte (epoch).'
}
$valeurs = @{}
foreach ($k in $def.Keys) { $valeurs[$k] = New-Object System.Collections.Generic.List[string] }
$membres = New-Object System.Collections.Generic.List[string]

foreach ($u in $users) {
    $l = 'sam="{0}",nom="{1}",conteneur="{2}"' -f (Esc $u.SamAccountName), (Esc $u.Name), (Esc (Conteneur $u.DistinguishedName))
    $logon = [int64]$dernierLogon[$u.SamAccountName]
    $logonTs = if ($logon -gt 0) { [DateTimeOffset]::FromFileTime($logon).ToUnixTimeSeconds() } else { 0 }

    $valeurs['ad_user_enabled'].Add("ad_user_enabled{$l} $([int][bool]$u.Enabled)")
    $valeurs['ad_user_locked_out'].Add("ad_user_locked_out{$l} $([int][bool]$u.LockedOut)")
    $valeurs['ad_user_password_expired'].Add("ad_user_password_expired{$l} $([int][bool]$u.PasswordExpired)")
    $valeurs['ad_user_password_never_expires'].Add("ad_user_password_never_expires{$l} $([int][bool]$u.PasswordNeverExpires)")
    $valeurs['ad_user_password_last_set_timestamp_seconds'].Add("ad_user_password_last_set_timestamp_seconds{$l} $(Ts $u.PasswordLastSet)")
    $valeurs['ad_user_last_logon_timestamp_seconds'].Add("ad_user_last_logon_timestamp_seconds{$l} $logonTs")
    $valeurs['ad_user_created_timestamp_seconds'].Add("ad_user_created_timestamp_seconds{$l} $(Ts $u.whenCreated)")

    foreach ($g in $u.memberOf) {
        $groupe = ($g -split '(?<!\\),', 2)[0].Substring(3) -replace '\\,', ','
        $membres.Add('ad_group_member{{groupe="{0}",sam="{1}"}} 1' -f (Esc $groupe), (Esc $u.SamAccountName))
    }
}

foreach ($k in $def.Keys) {
    $type, $aide = $def[$k] -split '\|', 2
    Metrique $k $type $aide
    $lignes.AddRange($valeurs[$k])
}

Metrique 'ad_group_member' 'gauge' 'Appartenance d''un utilisateur à un groupe (hors groupe principal).'
$lignes.AddRange($membres)

# --- Totaux
$actifs      = @($users | Where-Object Enabled).Count
$verrouilles = @($users | Where-Object LockedOut).Count
Metrique 'ad_users_total' 'gauge' 'Nombre de comptes utilisateurs du domaine, par état.'
$lignes.Add("ad_users_total{etat=""actif""} $actifs")
$lignes.Add("ad_users_total{etat=""desactive""} $($users.Count - $actifs)")
$lignes.Add("ad_users_total{etat=""verrouille""} $verrouilles")

$ordis = @(Get-ADComputer -Filter * -Properties Enabled)
Metrique 'ad_computers_total' 'gauge' 'Nombre de comptes ordinateurs du domaine.'
$lignes.Add("ad_computers_total $($ordis.Count)")

$groupes = @(Get-ADGroup -Filter *)
Metrique 'ad_groups_total' 'gauge' 'Nombre de groupes du domaine.'
$lignes.Add("ad_groups_total $($groupes.Count)")

# --- Santé du script
Metrique 'ad_metrics_dc_errors' 'gauge' 'Nombre de contrôleurs de domaine injoignables pour lire lastLogon.'
$lignes.Add("ad_metrics_dc_errors $dcErreurs")
Metrique 'ad_metrics_duration_seconds' 'gauge' 'Durée d''exécution du script.'
$lignes.Add("ad_metrics_duration_seconds $([math]::Round(((Get-Date) - $debut).TotalSeconds, 2).ToString([cultureinfo]::InvariantCulture))")
Metrique 'ad_metrics_last_run_timestamp_seconds' 'gauge' 'Dernière exécution réussie du script (epoch).'
$lignes.Add("ad_metrics_last_run_timestamp_seconds $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())")

# --- Écriture : UTF-8 sans BOM, LF, saut de ligne final, puis renommage
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tmp, (($lignes -join "`n") + "`n"), $utf8)
Move-Item -LiteralPath $tmp -Destination $sortie -Force
