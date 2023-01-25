#ps uptime calculator monitor: build 2
#######################################################
#original code: james keeler
#initially adapted for datto RMM by: chris eichermuller
#comprehensively modified by seagull
#uptime monitor :: build 3c/seagull

#region ----- DECLARATIONS ----
  Param(
    [string] $ComputerName = $env:computername,
    [int] $NumberOfDays = 30,
    [switch] $DebugInfo
  )

  $varError           = 0
  $NumberOfDays       = 30
  $crashCounter       = 0
  $rebootCounter      = 0
  $startUpID          = 6005
  $shutDownID         = 6006
  [timespan]$downtime = 0
  [timespan]$uptime   = New-TimeSpan -Days $NumberOfDays
  $currentTime        = Get-Date
  $minutesInPeriod    = $uptime.TotalMinutes
  $startingDate       = (Get-Date).adddays(-$NumberOfDays)
  $script:diag        = $null
  $script:blnWARN     = $false
  $strLineSeparator   = "---------"

$errInput = @"
We attempted to compare the device's uptime to the user-configured threshold in order to calculate a
trigger, but failed to handle the given threshold. This value must be an integer  no decimal places.
The threshold value we attempted to handle is listed below; please correct it into an integer.
=====================================================================================================
$($env:usrThreshold)
"@

$errWMI = @"
The monitor encountered an error. The WMI object 'LastBootupTime' in Win32_OperatingSystem could not be accessed.
The most likely culprit for this is a damaged WMI, which can be recovered using the Datto Agent Health Check
standalone utility (not the ComStore Component implementation). Download it at https://dat.to/ahcdl.

This is the unfiltered error PowerShell encountered when attempting to pull the WMI data:
=====================================================================================================
$($error)
=====================================================================================================

The script will now attempt to pull the Windows caption from the WMI. If the WMI database is indeed corrupted,
this will result in garbage data or nothing at all. Please scrutinise the result and act accordingly.
=====================================================================================================
$((get-WMiObject -computername $($env:computername) -Class win32_operatingSystem).caption)
=====================================================================================================
"@
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  Function EpochTime {[int][double]::Parse((Get-Date -UFormat %s))}
  
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message, $valUDF) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
    #write a UDF
    if ($env:usrUDF -gt 0) {
      #please don't edit this bit. think of platform load. -sgl
      try {
        $varLastReport = (Get-ItemProperty "HKLM:\Software\CentraStage" -Name "SGL-UptmMon" -ErrorAction stop)."SGL-UpTmMon"
      } catch {
        $varLastReport = 0
      }

      if (($(epochTime) - [int]$varLastReport) -gt 1800) {
        New-ItemProperty "HKLM:\Software\CentraStage" -Name "Custom$($env:usrUDF)" -Value "$($valUDF)" -Force -ea 0
        New-ItemProperty "HKLM:\Software\CentraStage" -Name "SGL-UpTmMon" -Value "$(epochtime)" -Force -ea 0
      }
    }
  } ## write-DRMMAlert

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
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

$events = Invoke-Command -ScriptBlock {`
	param($days,$up,$down) 
	Get-EventLog `
		-After (Get-Date).AddDays(-$days) `
		-LogName System `
		-Source EventLog `
	| Where-Object { 
		$_.eventID -eq  $up `
		-OR `
		$_.eventID -eq $down }
} -ArgumentList $NumberOfDays,$startUpID,$shutDownID -ErrorAction Stop
	
$sortedList = New-object system.collections.sortedlist
	
if ($events.Count -ge 1) {
	ForEach ($event in $events) {$sortedList.Add($event.timeGenerated, $event.eventID)}
} else {
	$sortedList.Add(0, 0)
}

For($i = 1; $i -lt $sortedList.Count; $i++) { 
	if (($sortedList.GetByIndex($i) -eq $startupID) -AND `
		($sortedList.GetByIndex($i) -ne $sortedList.GetByIndex($i-1))) {
      $duration = ($sortedList.Keys[$i] - $sortedList.Keys[$i-1])
      $downtime += $duration
      $rebootCounter++
	}	elseif (($sortedList.GetByIndex($i) -eq $startupID) -AND `
		($sortedList.GetByIndex($i) -eq $sortedList.GetByIndex($i-1))) { 	
      $tempevent = Invoke-Command -ScriptBlock {`
				param([datetime]$date, [string]$log)
				Get-EventLog `
					-Before $date.AddSeconds(1) `
					-Newest 1 `
					-LogName System `
					-Source EventLog `
					-EntryType Error `
					-ErrorAction "SilentlyContinue" | `
				Where-Object {$_.EventID -eq 6008}
			} -ArgumentList $sortedList.Keys[$i],$($eventlog.log)
			
		$lastEvent = [datetime](($tempevent.ReplacementStrings[1]).Replace([char]8206, " ")	+ " " + $tempevent.ReplacementStrings[0])
		$duration = ($sortedList.Keys[$i] - $lastEvent)
		$downtime += $duration
		$crashCounter++						
	}
}

$uptime -= $downtime
$results = "" | Select-Object Name, NumOfDays, NumOfCrashes, NumOfReboots, MinutesDown, MinutesUp, PercentDowntime, PercentUptime
$results.Name = $ComputerName
$results.NumOfDays = $NumberOfDays
$results.NumOfCrashes = $crashCounter
$results.NumOfReboots = $rebootCounter
$results.MinutesDown = "{0:n2}" -f $downtime.TotalMinutes
$results.MinutesUp = "{0:n2}" -f $uptime.TotalMinutes
$results.PercentDowntime = "{0:p4}" -f (1 - $uptime.TotalMinutes/$minutesInPeriod)
$results.PercentUptime = "{0:p4}" -f ($uptime.TotalMinutes/$minutesInPeriod)
$ip = $results.PercentUptime = "{0:p4}" -f ($uptime.TotalMinutes/$minutesInPeriod)

#get uptime calculation, rounded to two decimal places
try {
  $varUptime=[math]::Round((new-timespan -start $((Get-WmiObject -Class Win32_OperatingSystem -Property LastBootupTime) | % {$_.ConverttoDateTime($_.LastBootUpTime)}) -end (get-date)).totalDays,2)
  [int]$varUptimeINT = ($varUptime -as [string]).split(',|\.')[0]
} catch {
  $script:diag += "$($strLineSeparator)`r`nERROR: Could not ascertain bootup time. The device's WMI may be corrupted.`r`n$($strLineSeparator)`r`n$($errWMI)`r`n$($strLineSeparator)`r`n"
  write-DRMMAlert "$($strLineSeparator)`r`nERROR: Could not ascertain bootup time. The device's WMI may be corrupted.`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 1
}

#catch non-integer input in usrThreshold
try {
  [int]$varThreshold = $env:usrThreshold
} catch [System.Management.Automation.ArgumentTransformationMetadataException] {
  $script:diag += "$($strLineSeparator)`r`nERROR: usrThreshold input was not an integer`r`n$($strLineSeparator)`r`n$($errInput)`r`n$($strLineSeparator)`r`n"
  write-DRMMAlert "$($strLineSeparator)`r`nERROR: usrThreshold input was not an integer`r`n$($strLineSeparator)`r`n"
  write-DRMMDiag "$($script:diag)"
  exit 1
}

#only alert if we have a value and it is a breach
if ($varThreshold -gt 0) {
  if ($varUptimeINT -gt $varThreshold) {
    #New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "Custom$($env:udfUptime)" -PropertyType string -value "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | True" -Force
    write-DRMMAlert "ALERT: Uptime: $($varUptime) days :: Threshold: $($varThreshold) days" "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | True"
    write-DRMMDiag "$($script:diag)"
    exit 1
  } elseif ($varUptimeINT -le $varThreshold) {
    #New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "Custom$($env:udfUptime)" -PropertyType string -value "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | False" -Force
    write-DRMMAlert "HEALTHY : Uptime: $($varUptime) days :: Threshold: $($varThreshold) days" "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | False"
    write-DRMMDiag "$($script:diag)"
    exit 0
  }
#otherwise, just write our uptime and be done with it
} elseif ($varThreshold -le 0) {
  #New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "Custom$($env:udfUptime)" -PropertyType string -value "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | False" -Force
  write-DRMMAlert "HEALTHY : Uptime: $($varUptime) days :: Threshold: $($varThreshold) days" "Uptime: $($varUptime) days | Device uptime/30 days: $($ip) | False"
  write-DRMMDiag "$($script:diag)"
  exit 0
}