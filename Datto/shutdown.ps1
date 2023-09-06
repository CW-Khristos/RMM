# shutdown/reboot for the 21st century :: build 9/seagull
# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$usrAction,
  #  [Parameter(Mandatory=$true)]$rebootDay,
  #  [Parameter(Mandatory=$true)]$rebootTime,
  #  [Parameter(Mandatory=$true)]$rebootWindow,
  #  [Parameter(Mandatory=$true)]$usrTimeoutUnits,
  #  [Parameter(Mandatory=$true)]$usrTimeout,
  #  [Parameter(Mandatory=$false)]$usrMessage,
  #  [Parameter(Mandatory=$false)]$usrSuspendBitLocker
  #)
  [int]$varTimeout=0

  function check-Reboot {
    param(
      [Parameter(Mandatory=$true)]$window
    )
    $tz = get-timezone
    $rebootdiag = "Timezone : $($tz)`r`n"
    [datetime]$curTime = get-date -format "yyyy-MM-dd HH:mm:ss"
    $rebootdiag += "Current Time : $($curtime)`r`n"
    [datetime]$timeWindow = [datetime]$window
    $rebootdiag += "Scheduled Day : $($env:rebootDay)`r`n"
    [datetime]$runTime = $timeWindow.ToString('yyyy-MM-dd HH:mm:ss')
    $rebootdiag += "Scheduled Runtime : $($runtime)`r`n"
    [datetime]$startWindow = ($timeWindow).AddMinutes(-($env:rebootWindow))       # Minutes before scheduled time
    $rebootdiag += "Start Window : $($startwindow)`r`n"
    [datetime]$endWindow = ($timeWindow).AddMinutes(($env:rebootWindow))          # Minutes after scheduled time
    $rebootdiag += "End Window : $($endwindow)`r`n"
    if (($env:rebootDay -match $curTime.dayofweek) -and ($curTime -ge $startWindow) -and ($curTime -le $endWindow)) {
      #Execute stuff
      $rebootdiag += "Current Time : $($curTime) is Inside Window : $($env:rebootDay) - $($runTime) +-($($env:rebootWindow)min); Triggering Reboot`r`n"
      $script:diag += "$($rebootdiag)"
      write-output "$($rebootdiag)"
      return $true
    } else {
      #Do Nothing obviously
      $rebootdiag += "Current Time : $($curTime) is Outside Window : $($env:rebootDay) - $($runTime) +-($($env:rebootWindow)min); Exiting`r`n"
      $script:diag += "$($rebootdiag)"
      write-output "$($rebootdiag)"
      return $false
    }
  }

###################################################################################################################
#confirm parameters
write-output "Shutdown/Reboot Device"
write-output "============================"

write-output ": Action:                    $($env:usrAction)"                       #selection (shutdown/reboot)
write-output ": Suspend BitLocker Volumes: $($env:usrSuspendBitlocker)"             #bool

#translate time values to friendly and unfriendly ones
switch ($env:usrTimeoutUnits) {
  'H' {
    $varTimeout = ([int]$env:usrTimeout * 60) * 60
    write-output ": Timeout:                   $($env:usrTimeout) hours ($($varTimeout) seconds)"
  }
  'M' {
    $varTimeout = ([int]$env:usrTimeout * 60)
    write-output ": Timeout:                   $($env:usrTimeout) minutes ($($varTimeout) seconds)"
  }
  'S' {
    $varTimeout = [int]$env:usrTimeout
    write-output ": Timeout:                   $($env:usrTimeout) seconds"
  }
  default {
    write-output "! ERROR: Timeout units selection option must be H, M or S."
    write-output "  This error message should never appear."
    write-output "  Please contact support."
    exit 1
  }
}

#translate a blank message to "{NONE}"
if (($env:usrMessage -as [string]).Length -ge 1) {
  write-output ": Message:                   $($env:usrMessage)"                    #string
} else {
  write-output ": Message:                   {NONE}"
}

write-output "============================"
###################################################################################################################

$blnReboot = check-Reboot $env:rebootTime
write-output "Reboot Flag : $($blnReboot)"
if ($blnReboot) {
  try {
    #suspend bitlocker?
    if ($env:usrSuspendBitlocker -match 'true') {
      if ($((get-host).Version.Major) -lt 3) {
        write-output "! ERROR: Device has been instructed to suspend BitLocker, but"
        write-output "  the PowerShell version installed is too low to permit this action."
        write-output "  Please upgrade to at least PowerShell version 3.0 to enable"
        write-output "  the ability to suspend BitLocker before performing power tasks."
        write-output "  The shutdown or reboot will proceed as normal without this option."
      } else {
        $arrBitLockerVolumes = @()
        Get-BitLockerVolume | ? {$_.ProtectionStatus -eq 1} | % {$arrBitLockerVolumes += $_.MountPoint}
        foreach ($mount in $arrBitLockerVolumes) {
          write-output "- Suspending BitLocker for drive $($mount)..."
          Suspend-BitLocker -mountPoint $mount | select MountPoint,EncryptionMethod,ProtectionStatus | Out-String
        }
      }
    }

    #translate sub-thirty to "ASAFP"
    if ($varTimeout -le 30) {
      write-output ": Sub-thirty-second timeout detected."
      write-output "  It has been extended to 30 seconds to give the Component time"
      write-output "  to exit and post output data before the device goes down."
      $varTimeout=30
    }

    #perform the action
    if (($env:usrMessage -as [string]).Length -ge 1) {
      if ($env:usrAction -eq 'Reboot') {
        write-output "- Rebooting device in $($varTimeout) seconds..."
        shutdown /r /t $varTimeout /c "$($env:usrMessage)" /d p:2:1
      } else {
        write-output "- Shutting device down in $($varTimeout) seconds..."
        shutdown /s /t $varTimeout /c "$($env:usrMessage)" /d p:2:1
      }
    } else {
      if ($env:usrAction -eq 'Reboot') {
        write-output "- Rebooting device in $($varTimeout) seconds..."
        shutdown /r /t $varTimeout /d p:2:1
      } else {
        write-output "- Shutting device down in $($varTimeout) seconds..."
        shutdown /s /t $varTimeout /d p:2:1
      }
    }
    $script:diag += "Reboot has been set; system will reboot in $($varTimeout) $($env:usrTimeoutUnits)`r`n"
    write-output "Reboot has been set; system will reboot in $($varTimeout) $($env:usrTimeoutUnits)"
  } catch {
    write-output $_.scriptstacktrace
    write-output $_
  }
} elseif (-not $blnReboot) {
  $time = get-date.tostring('yyyy-MM-dd HH:mm:ss')
  $script:diag += "Current System Time $($time) not within configured Reboot Window : $($env:rebootDay), $($env:rebootTime) +-($($env:rebootWindow)min)`r`n"
  write-output "Current System Time $($time) not within configured Reboot Window : $($env:rebootDay), $($env:rebootTime) +-($($env:rebootWindow)min)`r`n"
}