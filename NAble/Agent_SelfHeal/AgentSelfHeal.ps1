# WINDOWS AGENT SELF-HEALING
# By Jonathan G. Weston <jonathan@thecomputerwarriors.com> and David Potter <david@thecomputerwarriors.com>
# $null check thanks to CJ Bledsoe
If (${env:ProgramFiles(x86)}) {
  $ProgramFilesPath = ${env:ProgramFiles(x86)}
} Else {
  $ProgramFilesPath = ${env:ProgramFiles}
}
$AgentConfigPath = $ProgramFilesPath + '\N-able Technologies\Windows Agent\config\'
$GoodApplianceBackupExists = Test-Path $AgentConfigPath\ApplianceConfig.xml.Good -PathType Leaf
$GoodServerBackupExists = Test-Path $AgentConfigPath\ServerConfig.xml.Good -PathType Leaf
[xml]$XmlAppliance = Get-Content -LiteralPath $AgentConfigPath\ApplianceConfig.xml
[xml]$XmlServer = Get-Content -LiteralPath $AgentConfigPath\ServerConfig.xml
$ApplianceID = $XmlAppliance.ApplianceConfig.ApplianceID
$BackupServerIP = $XmlServer.ServerConfig.BackupServerIP
If (($ApplianceID -ne -1) -And ($ApplianceID -ne $null)) {
  Copy-Item -LiteralPath $AgentConfigPath\ApplianceConfig.xml -Destination $AgentConfigPath\ApplianceConfig.xml.Good -Force
  Write-Host {Backed up ApplianceConfig.xml}
  If (($BackupServerIP -ne "localhost") -And ($BackupServerIP -ne $null)) {
    Copy-Item -LiteralPath $AgentConfigPath\ServerConfig.xml -Destination $AgentConfigPath\ServerConfig.xml.Good -Force
    Write-Host {Backed up ServerConfig.xml}
  } Else {
    Write-Host {Rejected bad ServerConfig.xml}
    If ($GoodServerBackupExists) {
      $AgentStopped = NET STOP "Windows Agent Service"
      Write-Host $AgentStopped[1]
      If ($AgentStopped[1] -eq 'The Windows Agent Service service could not be stopped.') {
        Write-Host {Terminating agent.exe via TaskKill...}
        TASKKILL /IM agent.exe /F
      }
      Copy-Item -LiteralPath $AgentConfigPath\ServerConfig.xml -Destination $AgentConfigPath\ServerConfig.xml.Bad -Force
      Copy-Item -LiteralPath $AgentConfigPath\ServerConfig.xml.Good -Destination $AgentConfigPath\ServerConfig.xml -Force
      Write-Host {Restored ServerConfig.xml from good backup}
      Start-Sleep -Seconds 2
      NET START "Windows Agent Service"
    } Else {
      Write-Host {FAILURE: No good backup of ServerConfig.xml exists!}
    }
  }
} Else {
  Write-Host {Rejected bad ApplianceConfig.xml}
  If ($GoodApplianceBackupExists) {
    Write-Host {The Windows Agent Service service is stopping...}
    $AgentStopped = NET STOP "Windows Agent Service"
    Write-Host $AgentStopped[1]
    If ($AgentStopped[1] -eq 'The Windows Agent Service service could not be stopped.') {
      Write-Host {Terminating agent.exe via TaskKill...}
      TASKKILL /IM agent.exe /F
    }
    Copy-Item -LiteralPath $AgentConfigPath\ApplianceConfig.xml -Destination $AgentConfigPath\ApplianceConfig.xml.Bad -Force
    Copy-Item -LiteralPath $AgentConfigPath\ApplianceConfig.xml.Good -Destination $AgentConfigPath\ApplianceConfig.xml -Force
    Write-Host {Restored ApplianceConfig.xml from good backup}
    If (($BackupServerIP -ne "localhost") -And ($BackupServerIP -ne $null)) {
      Write-Host {Since ApplianceConfig.xml was bad, skipping backup of ServerConfig.xml}
    } Else {
      Write-Host {Rejected bad ServerConfig.xml}
      If ($GoodServerBackupExists) {
        Copy-Item -LiteralPath $AgentConfigPath\ServerConfig.xml -Destination $AgentConfigPath\ServerConfig.xml.Bad -Force
        Copy-Item -LiteralPath $AgentConfigPath\ServerConfig.xml.Good -Destination $AgentConfigPath\ServerConfig.xml -Force
        Write-Host {Restored ServerConfig.xml from good backup}
      } Else {
        Write-Host {FAILURE: No good backup of ServerConfig.xml exists!}
      }
    }
    Start-Sleep -Seconds 2
    NET START "Windows Agent Service"
  } Else {
    Write-Host {FAILURE: No good backup of ApplianceConfig.xml exists!}
  }
}
