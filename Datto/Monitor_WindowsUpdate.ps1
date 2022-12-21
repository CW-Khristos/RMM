#Monitor - Windows Update
#nullzilla — 12/19/2022 5:42 PM
#Checking on and fixing some basic windows update health
#need to get around to adding failed install check too
#change the max age for builds to whatever you want
#there's also a threshold later in the script for how long before not having a recent update is an issue. that could be decreased if you have machines that are normally online/rebooted/patched regularly

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #VERSION FOR SCRIPT UPDATE
  $strSCR           = "Monitor_WindowsUpdate"
  $strVER           = [version]"0.1.0"
  $strREPO          = "RMM"
  $strBRCH          = "dev"
  $strDIR           = "Datto"
  $script:diag      = $null
  $script:blnWARN   = $false
  $script:blnBREAK  = $false
  $strLineSeparator = "---------"
  $logPath          = "C:\IT\Log\Monitor_WindowsUpdate"

#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRRMAlert

  function logERR($intSTG, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                                             #'ERRRET'=1 - ERROR DELETING FILE / FOLDER
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - ERROR DELETING FILE / FOLDER`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
      2 {                                                                             #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - NO ARGUMENTS PASSED, END SCRIPT`r`n$($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
      default {                                                                       #'ERRRET'=3+
        write-host "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - $($strErr)`r`n$($strLineSeparator)`r`n"
        $script:diag += "$($strLineSeparator)`r`n$((get-date).ToString('dd-MM-yyyy hh:mm:ss'))`t - Monitor_WindowsUpdate - $($strErr)`r`n$($strLineSeparator)`r`n`r`n"
      }
    }
  }

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
# Check Windows 10/11 version age
$OSname = Get-CimInstance Win32_OperatingSystem | select-object -ExpandProperty Caption
if ((Get-CimInstance Win32_OperatingSystem).version -like '10*' -and $OSname -notlike '*Server*') {
  if ($OSname -match 'Windows 10') {
    $MaxAge = "18" # Maximum age in months of builds you want to allow
    $CurrentDate = (get-date).AddMonths(-$MaxAge).ToString("yyMM")
    # Grab version and convert to numerical format, 19041 and older do not have DispalyVersion so we grab ReleaseID
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion) {
      $Version = ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion).replace('H1','05').replace('H2','11')
    } else { 
      $Version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId 
    }
  }
  if ($OSname -match 'Windows 11') {
    $MaxAge = "24" # Maximum age of builds you want to support in months 
    $CurrentDate = (get-date).AddMonths(-$MaxAge).ToString("yyMM")
    # Grab version and convert to numerical format
    $Version = ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion).replace('H1','05').replace('H2','11')
  }
  $Diff = $Version - $CurrentDate
  if ($Diff -lt '0') {
    $script:blnWARN = $true
    $script:blnBREAK = $true
    write-host "$($strLineSeparator)`r`n$($OSname) $($Version) is over $($MaxAge) months old, needs upgrading"
    $script:diag += "$($strLineSeparator)`r`n$($OSname) $($Version) is over $($MaxAge) months old, needs upgrading`r`n"
  }
}
# Check for disabled services
$disabled = Get-Service wuauserv, BITS, CryptSvc, RpcSs, EventLog | Where-Object -Property StartType -eq Disabled
if ($disabled) {
  $script:blnWARN = $true
  $script:blnBREAK = $true
  write-host "$($strLineSeparator)`r`nDisabled Services:`r`n$($disabled)"
  $script:diag += "$($strLineSeparator)`r`nDisabled Services:`r`n$($disabled)`r`n"
}
# Check if recent updates are installed
if (-not $script:blnBREAK) {
  try {
    $SSDStartDate = get-date
    $WindowsUpdateObject = new-object -ComObject Microsoft.Update.AutoUpdate
    $SearchSuccessDate = $WindowsUpdateObject.Results | select-object LastSearchSuccessDate
    $SSDLastDate = [datetime]$SearchSuccessDate.LastSearchSuccessDate
    $SSDLastDate = (get-date $SSDlastDate).AddHours(-5)
    $SSDDays = (new-timespan -Start $SSDLastDate -End $SSDStartDate | select-object days).days
    write-host "$($strLineSeparator)`r`nLast Search Success: $($SSDLastDate) ($($SSDDays) days ago)"
    $script:diag += "$($strLineSeparator)`r`nLast Search Success: $($SSDLastDate) ($($SSDDays) days ago)`r`n"
    $ISDStartDate = get-date
    $InstallSuccessDate = $windowsUpdateObject.Results | select-object LastInstallationSuccessDate
    $ISDLastDate = [datetime]$InstallSuccessDate.LastInstallationSuccessDate
    $ISDLastDate = (get-date $ISDlastDate).AddHours(-5)
    $ISDDays = (new-timespan -Start $ISDLastDate -End $ISDStartDate | select-object days).days
    write-host "$($strLineSeparator)`r`nLast Installation Success: $($ISDLastDate) ($($ISDDays) days ago)"
    $script:diag += "$($strLineSeparator)`r`nLast Installation Success: $($ISDLastDate) ($($ISDDays) days ago)`r`n"
    $LastMonth = (get-date).addmonths(-1).ToString("yyyy-MM")
    $ThisMonth = (get-date).ToString("yyyy-MM")
    $Session = new-object -ComObject 'Microsoft.Update.Session'
    $Searcher = $Session.CreateUpdateSearcher()
    $HistoryCount = $Searcher.GetTotalHistoryCount()
    if ($HistoryCount -gt 0) {
      $xx = $($Searcher.QueryHistory(0, $HistoryCount) | select-object Title, Date, Operation, Resultcode | 
        where-object {(($_.Operation -like 1) -and ($_.Resultcode -match '[123]'))} | select-object Title)
    } else {
      $xx = $(Get-Hotfix | where-object {$_.hotfixid -match 'KB\d{6,7}'} | select-object Hotfixid)
    }
    if (!$xx) {
      $script:blnWARN = $false
      write-host "$($strLineSeparator)`r`nWARNING - No updates returned"
      $script:diag += "$($strLineSeparator)`r`nWARNING - No updates returned`r`n"
    } else {
      $xx = $xx | where-object {(($_ -match "($($LastMonth)|$($ThisMonth)) (Security Monthly Quality Rollup|Cumulative Update)") -or ($_ -match "Feature update"))}
      if (!$xx) {
        write-host "$($strLineSeparator)`r`nWARNING - No recent rollup/cumulative/feature update detected"
        write-host "$($strLineSeparator)`r`nLast updates:"
        $xx | select-object -ExpandProperty Title -First 1
        $script:diag += "$($strLineSeparator)`r`nWARNING - No recent rollup/cumulative/feature update detected`r`n"
        $script:diag += "$($strLineSeparator)`r`nLast updates:`r`n"
        $script:diag += $xx | select-object -ExpandProperty Title -First 1
        $script:diag += "`r`n$($strLineSeparator)`r`n"
        # If last install succes was recent, let's not fail out
        if ($ISDDays -lt 30 -or $ISDDays -gt 153000) {
          $script:blnWARN = $false
        } elseif ($ISDDays -gt 30 -and $ISDDays -lt 153000) {
          $script:blnWARN = $true
          write-host "$($strLineSeparator)`r`nWARNING - No recent rollup/cumulative/feature update detected"
          $script:diag += "$($strLineSeparator)`r`nWARNING - No recent rollup/cumulative/feature update detected`r`n"
        }
      } else {
        $script:blnWARN = $false
        write-host "$($strLineSeparator)`r`nRecent rollup or cumulative update detected:"
        $xx | select-object -ExpandProperty Title -First 1
        write-host "$($strLineSeparator)"
        $script:diag += "$($strLineSeparator)`r`nRecent rollup or cumulative update detected:`r`n"
        $script:diag += $xx | select-object -ExpandProperty Title -First 1
        $script:diag += "`r`n$($strLineSeparator)`r`n"
      }
    }
  } catch {
    $script:blnWARN = $true
    write-host "$($strLineSeparator)`r`nERROR - Failed to check recent updates : Check Diagnostics`r`n$($strLineSeparator)"
    $script:diag += "$($strLineSeparator)`r`nERROR - Failed to check recent updates : Check Diagnostics`r`n$($strLineSeparator)`r`n"
  }
}
$script:diag += "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - Monitor_WindowsUpdate Complete`r`n$($strLineSeparator)`r`n"
write-host "$($strLineSeparator)`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - Monitor_WindowsUpdate Complete`r`n$($strLineSeparator)"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
if ($blnLOG) {
  $script:diag | out-file $logPath
}
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "Monitor_WindowsUpdate : Execution Completed with Warnings : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  #exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "Monitor_WindowsUpdate : Healthy : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  #exit 0
}
#END SCRIPT
#------------