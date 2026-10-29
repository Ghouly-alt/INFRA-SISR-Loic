# Import des utilisateurs du domaine gsblolo.local depuis un CSV (colonnes : Prenom;Nom;Fonction).
# A executer sur le controleur de domaine en PowerShell administrateur.
# Le mot de passe initial est demande au lancement : il n'est pas stocke dans le depot.

Import-Module ActiveDirectory
$CSVData = Import-Csv -Path (Join-Path $PSScriptRoot 'utilisateurs.csv') -Delimiter ';' -Encoding UTF8
$MotDePasse = Read-Host 'Mot de passe initial des comptes' -AsSecureString

foreach ($Utilisateur in $CSVData) {
    $UtilisateurPrenom = $Utilisateur.Prenom
    $UtilisateurNom = $Utilisateur.Nom
    $UtilisateurLogin = ($UtilisateurPrenom).Substring(0,1) + "." + $UtilisateurNom
    $UtilisateurEmail = "$UtilisateurLogin@gsblolo.local"
    $UtilisateurFonction = $Utilisateur.Fonction

    # Verifier la presence de l'utilisateur dans l'AD
    if (Get-ADUser -Filter {SamAccountName -eq $UtilisateurLogin}) {
        Write-Warning "L'identifiant $UtilisateurLogin existe deja dans l'AD"
    }
    else {
        New-ADUser -Name "$UtilisateurNom $UtilisateurPrenom" `
                   -DisplayName "$UtilisateurNom $UtilisateurPrenom" `
                   -GivenName $UtilisateurPrenom `
                   -Surname $UtilisateurNom `
                   -SamAccountName $UtilisateurLogin `
                   -UserPrincipalName "$UtilisateurLogin@gsblolo.local" `
                   -EmailAddress $UtilisateurEmail `
                   -Title $UtilisateurFonction `
                   -Path "OU=Utilisateurs,OU=Services,DC=gsblolo,DC=local" `
                   -AccountPassword $MotDePasse `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true

        Write-Output "Creation de l'utilisateur : $UtilisateurLogin ($UtilisateurNom $UtilisateurPrenom)"
    }
}
