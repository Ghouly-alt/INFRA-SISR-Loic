# verif_ad.ps1 - Contrôle complet d'AD-DC (PowerShell en administrateur)
"== Service windows_exporter"; Get-Service windows_exporter | Format-Table Name,Status,StartType -AutoSize
"== Services AD"; Get-Service NTDS,DNS,Kdc,Netlogon,ADWS,W32Time,DFSR | Format-Table Name,Status,StartType -AutoSize
"== Pare-feu 9182"; Get-NetFirewallRule -DisplayName "*windows_exporter*" | ForEach-Object { "{0} | actif {1} | {2} | depuis {3}" -f $_.DisplayName, $_.Enabled, $_.Action, (($_ | Get-NetFirewallAddressFilter).RemoteAddress -join ',') }
"== Tâche planifiée"; Get-ScheduledTaskInfo -TaskName "Prometheus - utilisateurs AD" | Format-List LastRunTime,LastTaskResult,NextRunTime
"== Droits C:\Scripts"; icacls C:\Scripts
"== Fichier ad_users.prom"; $f = Get-Item "C:\Program Files\windows_exporter\textfile_inputs\ad_users.prom"; "écrit il y a {0:N0} s" -f ((Get-Date) - $f.LastWriteTime).TotalSeconds
"== Stratégie de verrouillage"; Get-ADDefaultDomainPasswordPolicy | Format-List LockoutThreshold,LockoutDuration,LockoutObservationWindow
"== Émulateur PDC / source de temps"; (Get-ADDomain).PDCEmulator; w32tm /query /source
"== Licence"; cscript //nologo C:\Windows\System32\slmgr.vbs /xpr
"== Démarré le"; (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
"== Disque C:"; Get-PSDrive C | ForEach-Object { "{0:N1} Go libres sur {1:N1} Go" -f ($_.Free/1GB), (($_.Used + $_.Free)/1GB) }
"== Mises à jour Windows en attente"; $u = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0").Updates; "$($u.Count) mise(s) à jour"; $u | ForEach-Object Title
