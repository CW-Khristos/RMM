<# 
.SYNOPSIS 
    Automate rotation of SuperMicro IPMI Interface passwords and export BIOS / IPMI Configurations

.DESCRIPTION
    Script will automatically download SuperMicro Update Manager (SUM) & SMCIPMITool utilities
    Script will generate a randomized password string up to a configurable character length
    Script can be configured to use either SUM or SMCIPMITool to automate rotation of SuperMicro IPMI Interface passwords (requires administrative IPMI / BMC username & password)
    Script can be configured to use either SUM or SMCIPMITool to automate export of BIOS / IPMI / RAID Configurations
      Notes : Changing IPMI / BMC user passwords requires passing of IPMI / BMC User ID (1 - Anonymous, 2 - ADMIN)
             RAID Configuration export requires Node product key be activated to execute
             Both utilities require the passing of the IPMI / BMC IP Address and administrative IPMI / BMC username & password to change user passwords
             SMCIPMITool requires the passing of the IPMI / BMC IP Address and administrative username and password to perform *all* functions
             SMCIPMITool cannot export RAID Configurations
 
.NOTES
    Version        : 0.1.0 (31 January 2022)
    Creation Date  : (31 January 2022
    Purpose/Change : Automate rotation of SuperMicro IPMI Interface passwords and export BIOS / IPMI Configurations
    File Name      : IPMIConfig_0.1.0.ps1 
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release

.TODO
    
#>

#REGION ----- DECLARATIONS ----
  Param(
    $i_Tool,
    $i_IPMIaddress,
    $i_IPMIuser,
    $i_IPMIpwd,
    $i_PwdLength,
    $i_UserID,
    $i_NewPwd
  )
  arrPWD = @(
    "!"
    "@"
    "#"
    "$"
    "%"
    "^"
    "&"
    "*"
  )
  #SUPERMICRO UPDATE MANAGER (SUM)
  $sumZIP = "C:\IT\SuperMicro\SUM.zip"
  $sumBAK = "C:\IT\SuperMicro\Backups\SUM"
  $sumEXE = "C:\IT\SuperMicro\SUM\sum.exe"
  $srcSUM = "https://github.com/CW-Khristos/scripts/raw/dev/SuperMicro/SUM.zip"
  #SUPERMICRO SMCIPMITOOL
  $smcipmiZIP = "C:\IT\SuperMicro\SMCIPMITool.zip"
  $smcipmiBAK = "C:\IT\SuperMicro\Backups\SMCIPMITOOL"
  $smcipmiEXE = "C:\IT\SuperMicro\SMCIPMITool\smcipmitool.exe"
  $srcSMCIPMI = "https://github.com/CW-Khristos/scripts/raw/dev/SuperMicro/SMCIPMITool.zip"

  [System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000000
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function Get-EpochDate ($epochDate) {                                 #Convert Epoch Date Timestamps to Local Time
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($epochDate))
  } ## Get-EpochDate

  function Get-ProcessOutput {
    Param (
      [Parameter(Mandatory=$true)]$FileName,
      $Args
    )

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.WindowStyle = "Hidden"
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.FileName = $FileName
    if($Args) {$process.StartInfo.Arguments = $Args}
    $out = $process.Start()

    $StandardError = $process.StandardError.ReadToEnd()
    $StandardOutput = $process.StandardOutput.ReadToEnd()

    $output = New-Object PSObject
    $output | Add-Member -type NoteProperty -name StandardOutput -Value $StandardOutput
    $output | Add-Member -type NoteProperty -name StandardError -Value $StandardError
    return $output
  } ## Get-ProcessOutput
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
if (-not (test-path -path "C:\IT\SuperMicro")) {
  new-item -path "C:\IT\SuperMicro" -itemtype directory
}
if (-not (test-path -path "C:\IT\SuperMicro\Backups")) {
  new-item -path "C:\IT\SuperMicro\Backups" -itemtype directory
}
if (-not (test-path -path "C:\IT\SuperMicro\Backups\SUM")) {
  new-item -path "C:\IT\SuperMicro\Backups\SUM" -itemtype directory
}
if (-not (test-path -path "C:\IT\SuperMicro\Backups\SMCIPMITOOL")) {
  new-item -path "C:\IT\SuperMicro\Backups\SMCIPMITOOL" -itemtype directory
}
#GENERATE RANDOMIZED PASSWORD UP TO LEN($i_PwdLength)
if (($i_PwdLength -eq 0) -or ($i_PwdLength -lt 8) -or ($i_PwdLength -gt 19)) {
  $i_PwdLength = 8
}
if (($i_NewPwd -eq $null) -or ($i_NewPwd -eq "NULL")) {
  $blnPass = $false
  while (-not $blnPass) {
    $i_NewPwd = -join ((33..33) + (35..38) + (42..42) + (50..57) + (63..72) + (74..75) + (77..78) + (80..90) + (97..104) + (106..107) + (109..110) + (112..122) | Get-Random -Count $i_PwdLength | ForEach-Object {[char]$_})
    #PASSWORD COMPLEXITY CHECK
    foreach ($char in $arrPWD) {
      if ($i_NewPwd -match $char) {
        $blnPass = $true
        break
      }
    }
  }
} else {
  $i_NewPwd = $i_NewPwd
}
#SELECT WHICH UTILITY TO USE BASED ON PASS PARAMETER($i_Tool)
switch ($i_Tool.toupper()) {
  "SUM" {                                                               #SUPERMICRO UPDATE MANAGER (SUM) CALLS
    if (test-path -path $sumEXE -pathtype leaf) {                       #DOWNLOAD SUM IF NEEDED
    } elseif (-not (test-path -path $sumEXE -pathtype leaf)) {
      write-host " - DOWNLOAD SUPERMICRO UPDATE MANAGER (SUM)" -foregroundcolor red
      try {
        start-bitstransfer -erroraction stop -source $srcSUM -destination $sumZIP
        expand-archive $sumZIP -destinationpath "C:\IT\SuperMicro\SUM"
      } catch {
        $web = new-object system.net.webclient
        $web.downloadfile($srcSUM, $sumZIP)
        #EXTRACT SUM
        $shell = New-Object -ComObject shell.application
        $zip = $shell.NameSpace($smcipmiZIP)
        MkDir("C:\IT\SuperMicro\SUM")
        foreach ($item in $zip.items()) {
          $shell.Namespace("C:\IT\SuperMicro\SUM").CopyHere($item)
        }
      }
      remove-item $sumZIP -erroraction silentlycontinue
    }
    #SET IPMI / BMC USER PASSWORD
    if (($i_IPMIuser -eq $null) -or ($i_IPMIpwd -eq $null)) {
      write-host "SUM - CANNOT SET IPMI / BMC USER PASSWORD WITHOUT IPMI / BMC LOGIN" -foregroundcolor red
    } elseif (($i_IPMIuser -ne $null) -and ($i_IPMIpwd -ne $null)) {
      write-host "SUM - SETTING IPMI / BMC USER PASSWORD" -foregroundcolor yellow
      $pwdoutput = Get-ProcessOutput -FileName $sumEXE "-c SetBmcPassword -i $i_IPMIaddress -u $i_IPMIuser -p $i_IPMIpwd --user_id $i_UserID --new_password $i_NewPwd --confirm_password $i_NewPwd"
      #PARSE SUM OUTPUT LINE BY LINE
      $lines = $pwdoutput.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      foreach ($line in $lines) {
        if ($line -ne $null) {
          write-host $line
        }
      }
    }
    #BACKUP BIOS CONFIGURATIONS
    write-host "SUM - BACKUP BIOS CONFIGURATIONS" -foregroundcolor yellow
    $output = Get-ProcessOutput -FileName $sumEXE "-c GetCurrentBiosCfg --file $sumBAK\SUM_BIOS_BACKUP.config --overwrite"
    #PARSE SUM OUTPUT LINE BY LINE
    $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($line in $lines) {
      if ($line -ne $null) {
        write-host $line
      }
    }
    #BACKUP IPMI / BMC CONFIGURATIONS
    write-host "SUM - BACKUP IPMI / BMC CONFIGURATIONS" -foregroundcolor yellow
    $output = Get-ProcessOutput -FileName $sumEXE "-c GetBmcCfg --file $sumBAK\SUM_BMC_BACKUP.config --overwrite"
    #PARSE SUM OUTPUT LINE BY LINE
    $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($line in $lines) {
      if ($line -ne $null) {
        write-host $line
      }
    }
    #BACKUP RAID CONFIGURATIONS
    write-host "SUM - BACKUP RAID CONFIGURATIONS" -foregroundcolor yellow
    $output = Get-ProcessOutput -FileName $sumEXE "-c GetRaidCfg --file $sumBAK\SUM_RAID_BACKUP.xml --overwrite"
    #PARSE SUM OUTPUT LINE BY LINE
    $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($line in $lines) {
      if ($line -ne $null) {
        write-host $line
      }
    }
  }
  "SMCIPMITOOL" {                                                       #SMCIPMITOOL CALLS
    if (($i_IPMIaddress -eq $null) -or ($i_IPMIuser -eq $null) -or ($i_IPMIpwd -eq $null)) {
      write-host "SMCIPMITOOL - UNABLE TO PERFORM COMMANDS WITHOUT IPMI / BMC ADDRESS OR LOGIN" -foregroundcolor red
    } elseif (($i_IPMIaddress -ne $null) -and ($i_IPMIuser -ne $null) -and ($i_IPMIpwd -ne $null)) {
      if (-not (test-path -path $smcipmiEXE -pathtype leaf)) {          #DOWNLOAD SMCIPMITOOL IF NEEDED
        write-host " - DOWNLOADING SUPERMICRO SMCIPMITOOL" -foregroundcolor red
        try {
          start-bitstransfer -erroraction stop -source $srcSMCIPMI -destination $smcipmiZIP
          expand-archive $smcipmiZIP -destinationpath "C:\IT\SuperMicro\SMCIPMITool"
        } catch {
          $web = new-object system.net.webclient
          $web.downloadfile($srcSMCIPMI, $smcipmiZIP)
          #EXTRACT SMCIPMITOOL
          $shell = New-Object -ComObject shell.application
          $zip = $shell.NameSpace($smcipmiZIP)
          MkDir("C:\IT\SuperMicro\SMCIPMITool")
          foreach ($item in $zip.items()) {
            $shell.Namespace("C:\IT\SuperMicro\SMCIPMITool").CopyHere($item)
          }
        }
        remove-item $smcipmiZIP -erroraction silentlycontinue
      }
      #SET IPMI / BMC USER PASSWORD
      write-host "SMCIPMITOOL - SETTING IPMI / BMC USER PASSWORD" -foregroundcolor yellow
      $pwdoutput = Get-ProcessOutput -FileName $smcipmiEXE "$i_IPMIaddress $i_IPMIuser $i_IPMIpwd user setpwd $i_UserID $i_NewPwd"
      #PARSE SMCIPMITOOL OUTPUT LINE BY LINE
      $lines = $pwdoutput.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      foreach ($line in $lines) {
        if ($line -ne $null) {
          write-host $line
        }
      }
      #BACKUP IPMI / BMC CONFIGURATIONS AS TEXT
      write-host "SMCIPMITOOL - BACKUP IPMI / BMC CONFIGURATIONS AS TEXT" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $smcipmiEXE "$i_IPMIaddress $i_IPMIuser $i_IPMIpwd ipmi oem getcfg $smcipmiBAK\SMCIPMITOOL_BMC_BACKUP.config"
      #PARSE SMCIPMITOOL OUTPUT LINE BY LINE
      $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      foreach ($line in $lines) {
        if ($line -ne $null) {
          write-host $line
        }
      }
      #BACKUP IPMI / BMC CONFIGURATIONS AS BINARY
      write-host "SMCIPMITOOL - BACKUP IPMI / BMC CONFIGURATIONS AS BINARY" -foregroundcolor yellow
      $output = Get-ProcessOutput -FileName $smcipmiEXE "$i_IPMIaddress $i_IPMIuser $i_IPMIpwd ipmi oem backupcfg $smcipmiBAK\SMCIPMITOOL_BMC_BACKUP.bin"
      #PARSE SMCIPMITOOL OUTPUT LINE BY LINE
      $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
      foreach ($line in $lines) {
        if ($line -ne $null) {
          write-host $line
        }
      }
    }
  }
}
#RETURN NEW IPMI / BMC PASSWORD TO NABLE
if ($pwdoutput -match "The BMC password is set") {
  $o_Pwd = $i_NewPwd
}
#END SCRIPT
#------------