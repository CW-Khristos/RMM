$blnNone = $false
#Set none detected in var
$backupproduct="None detected|"
$software = @("AhsayOBM*","AhsayACB*","Handy Backup","StorageCraft*","*ShadowSnap*","*ShadowProtect*",
  "Windows NT Backup - Restore Utility","1SEO Technologies*","Acronis*","Barracuda Backup Agent","CATS Backup*",
  "Carbonite Safe Server Backup*","Carbonite Server Backup*","Carbonite*","CloudBerry Backup*","Datto Windows Agent",
  "1PR CloudBackup*","Abele Pro Backup*","ABLRemoteBackup*","Acapella Online Backup*","AccuNet Managed Backup*",
  "ACTChoice Backup*","ADVYON Umbrella Backup*","Aegis DataShield Online Backup Bare Metal Edition","AFScott Cloud Backup*",
  "Agente de Backup em Nuvem","AIE Backup*","airbackup*","Alltech Cloud Backup*","Altaro Backup FS","Altaro Hyper-V Backup",
  "Altaro VM Backup","Altrim Cloud Backup","Altrim Cloud Backup","*Arcserve*","ArcSoft TotalMedia Backup & Record*",
  "Assertus BackUp Service*","Autotask Endpoint Backup*","AvarTec Online Backup*","Axis Online Backup*","Backup and Sync from Google*",
  "Backup Direct Professional*","Backup Express*","Backup for Workgroups*","BackUp Maker*","Backup Manager*","Backup Phoenix*",
  "Backup4all*","BackupAssist*","BackupChain*","BackUpDutyLite*","BackupMist*","Barule Group Backup*","BCOS Backup*","BDR Backup Agent*",
  "BDS Online Backup*","Boyer Online Backup*","*ARCserve Backup*","Clarity Technology Solutions Offsite Backup Service*",
  "CloudBackup*","Cobian Backup*","CodeTwo Backup*","Commander NE Automated Backup*","COMODO BackUp*","Contmatic Phoenix - Backup*",
  "D-Tech Online Backup*","DataVault Online Backup*","DDB Backup For Servers*","Digicel Cloud Backup*","DSI Backup Agent*",
  "Dynamic Vault Offsite Backup*","EaseUS Backup*","EaseUS Todo Backup*","eBackUp*","EMC Avamar Backup*","EVault*","FBackup*",
  "Genie Backup*","GreenFolders Backup*","Hollander Backup*","Hyperoo ContinuousBackup*","IBackup*","IDEXX Data Backup and Recovery*",
  "Imagine Backups*","Infrascale Data Protection*","Iperius Backup*","iPoint Online Backup*","Jungle Disk Simply Backup*",
  "Kaseya Backup and Disaster Recovery*","KineticCloud Backup For Servers*","Les Solutions Backup En Ligne*","LG CyberLink PowerBackup*",
  "LiveVault Backup*","LogMeIn Backup*","MBA Backup*","MEDITECH BackupJob*","Memeo Instant Backup*","Microsoft Azure Backup*",
  "My Hive Drive Backup*","My Secure Backup Server*","MySQLBackupFTP*","MozyHome Backup*","MozyPro Backup*","NAKIVO Backup & Replication*",
  "NetVault Backup*","NovaBACKUP*","Novocure A-Click Backup*","Office Practicum Backup Service*","Offsite Backups*",
  "Online Backup and Recovery*","online backup Bare Metal Edition*","Online Backup Live Professional*","Online Backup VM Edition*",
  "online backup*","OnPointIT Managed Backups*","OSPC Online Backup and Recovery Manager*","OTS Online Backup*",
  "Patent Consulting Group Online Backup*","PC Auto Backup*","PC Backup Server*","Pervasive Backup Agent*","PHD Virtual Backup*",
  "Profit Backup*","Prolific Backup*","ProvenBackup Online Backup*","Quest Backup*","QuickBooks Online Backup*","Rackspace Cloud Backup*",
  "Rapid Backup*","Remote Backup*","Remote Data Backup*","Replibit Backup Agent*","Replay*","Revon Backups*","Secure Backup and Fileshare*",
  "SQL Backup Master*","SQLBackupAndFTP*","Stellar Phoenix Windows Backup Recovery*","Stronghold Data Corporate Backup*",
  "Symantec Backup Exec*","Symantec NetBackup*","Synology Cloud Station Backup*","SysTools SQL Backup Recovery*",
  "TekDoc Backup*","TekDoc Online Backup*","TenmastRemoteBackup*","THUMBTECHS Cloud Backup*","TotalCare Backup Solutions*",
  "Unitrends Agent*","UrBackup Server*","Veeam*","VembuImageBackupClient*","VembuVMBackup*","VERITAS Backup Exec*","VisionCPS Backup*",
  "vRanger Backup & Replication*","WD Align - Powered by Acronis*","WD Backup*","Worry-Free Backup*","WS Backup Service*","Yosemite Backup*")

clear-host
#COLLECT ALL APPLICATIONS
#32 BIT REGISTRY
$installed = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select DisplayName)
#64BIT REGISTRY
$installed += (Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select DisplayName)
#EVALUATE COLLECTED APPLICATIONS
foreach ($product in $software) {
  if ($installed.displayname -contains $product.replace('*', '')) {
    if ($backupproduct -eq "None detected|") {
      $backupproduct = "$($product.replace('*', ''))|"
    } elseif ($backupproduct -ne "None detected|") {
      $backupproduct += "$($product.replace('*', ''))|"
    }
    write-output "$($product.replace('*', '')) is installed"
  } elseif ($installed.displayname -notcontains $product) {
    write-output "$($product.replace('*', '')) is NOT installed"
  }
}

#Check for Autotask Endpoint Backup
if (Get-Service | where-object {$_.name -like 'Autotask_DA.VssHelper'}){
  write-output "Autotask Endpoint Backup is installed"
  $backupproduct += "Autotask Endpoint Backup|"
}

#Check for Datto File Protection
if (Get-Service | where-object {$_.name -like 'Datto_VA.VssHelper'}){
  write-output "Datto File Protection is installed"
  $backupproduct += "Datto File Protection|"
}
    

#Check for Backup Exec
if (Get-Service | where-object {$_.name -like '*BackupExec*'}){
  write-output "BackupExec is installed"
  $backupproduct += "BackupExec - Conflict With BCDR|"
}


#Check for Acronis
if (Get-Service | where-object {$_.name -like 'Acronis*'}){
  write-output "Acronis Backup and Recovery is installed"
  $backupproduct += "Acronis - Conflict With Datto BCDR|"
}

#Check for Attix Backup
if (Get-Service | where-object {$_.name -like 'Attix*'}){
  write-output "Attix Backup is installed"
  $backupproduct += "Attix Backup|"
}

#Check for BackupAssist Backup
if (Get-Service | where-object {$_.name -like 'BackupAssist*'}){
  write-output "BackupAssist is installed"
  $backupproduct += "BackupAssist|"
}

write-output "`r`nDetected backup Product: $($backupproduct)"
new-itemproperty -path "HKLM:\Software\Centrastage" -name $env:custom -value "$($backupproduct)" -force