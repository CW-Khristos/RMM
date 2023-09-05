<#
.SYNOPSIS 
    Modification of DRMM Event Log monitoring to reduce duplication of alerts

.DESCRIPTION 
    Modification of DRMM Event Log monitoring to reduce duplication of alerts
    Only searches and alerts on the most recent specified Time Range in the specified Event Log
 
.NOTES
    Version        : 0.1.1 (05 September 2023)
    Creation Date  : 04 August 2022
    Purpose/Change : Modification of DRMM Event Log monitoring to reduce duplication of alerts
    File Name      : EventLog_Monitoring_0.1.0.ps1
    Author         : Christopher Bledsoe - cbledsoe@ipmcomputers.com
    Supported OS   : Server 2012R2 and higher
    Requires       : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release
    
To Do:

#>

#First Clear any variables
#Remove-Variable * -ErrorAction SilentlyContinue
  
#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$i_LogRange,
  #  [Parameter(Mandatory=$true)]$i_EventLog,
  #  [Parameter(Mandatory=$true)]$i_EventSource,
  #  [Parameter(Mandatory=$true)]$i_EventID,
  #  [Parameter(Mandatory=$true)]$i_EventType,
  #  [Parameter(Mandatory=$true)]$i_EventDescription,
  #  [Parameter(Mandatory=$true)]$i_EventThreshold
  #) 
  $script:diag = $null
  $script:intTotal = 0
  $script:hashEvents = @{}
  $script:hashMessage = @{}
  $script:hashDetails = @{}
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  }

  function write-DRRMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  }

  function MapLevel {
    param (
      $strLevel
    )
    switch ($strLevel.toupper()) {
      "INFO" {return 0}
      "FATAL" {return 1}
      "ERROR" {return 2}
      "WARNING" {return 3}
      "INFORMATION" {return 4}
      "DEBUG" {return 5}
      "TRACE" {return 6}
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
    $ScriptStopTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
    $total = ((((($Hours * 60) + $Minutes) * 60) + $Seconds) * 1000) + $Milliseconds
    $mill = [string]($total / 1000)
    $mill = $mill.split(".")[1]
    $mill = $mill.SubString(0,[math]::min(3,$mill.length))
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
    write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.2") {
  $script:diag += "Informational - Unsupported OS. Only Server 2012R2 and up are supported.`r`n`r`n"
}
#HANDLE MULTIPLE EVENT TYPES
if ($env:i_EventID -match ",") {
  $arrID = $env:i_EventID.split(",")
} elseif ($env:i_EventID -notmatch ",") {
  $arrID = [int]$env:i_EventID
}
#HANDLE MULTIPLE EVENT TYPES
if ($env:i_EventType -match ",") {
  $types = $env:i_EventType.split(",")
  foreach ($type in $types) {
    if (($null -ne $type) -and ($type -ne "")) {
      $strType = MapLevel "$($type)"
      $strTypes = "$($strTypes)$($strType),"
    }
  }
  $strTypes = $strTypes.substring(0,$strTypes.length - 1)
  $arrTypes = $strTypes.split(",")
} elseif ($env:i_EventType -notmatch ",") {
  [int]$i_EventType = MapLevel "$($env:i_EventType)"
}
write-output "ID : $($arrID)"
write-output "LEVEL : $($arrTypes)"
#CAPTURE TOTAL EVENTS MATCHING FILTERS
$logInfo = @{
  LogName      = "$($env:i_EventLog)"
  ProviderName = "$($env:i_EventSource)"
  ID           = $arrID
  Level        = $arrTypes
}
$LogEvents = Get-WinEvent -FilterHashtable $logInfo
$script:intTotal = $LogEvents.count
#CAPTURE EVENTS MATCHING FILTERS WITHIN SPECIFIED TIME RANGE
$logInfo = @{
  LogName      = "$($env:i_EventLog)"
  ProviderName = "$($env:i_EventSource)"
  ID           = $arrID
  Level        = $arrTypes
  StartTime    = (get-date).AddHours(-$($env:i_LogRange))
  EndTime      = (get-date).AddMinutes(-2)
}
$FilteredEvents = Get-WinEvent -FilterHashtable $logInfo
$script:diag += "----------------------------------`r`n"
$script:diag += "COLLECTING EVENTS MATCHING THE FOLLOWING :`r`n"
$script:diag += "`tLogName : $($env:i_EventLog)`tSource : $($env:i_EventSource)`tEvent ID : $($env:i_EventID)`tEvent Type : $($env:i_EventType)`tTime Range (Hours) : $($env:i_LogRange)`r`n"
$script:diag += "----------------------------------`r`n`r`n"
$script:diag += "----------------------------------`r`n"
$script:diag += "TOTAL EVENTS : $($script:intTotal)`r`n"
$script:diag += "----------------------------------`r`n"
$script:diag += "EVENTS WITHIN PAST $($env:i_LogRange) HOURS : $($FilteredEvents.Count)`r`n"
write-output "----------------------------------"
write-output "COLLECTING EVENTS MATCHING THE FOLLOWING :"
write-output "`tLogName : $($env:i_EventLog)`tSource : $($env:i_EventSource)`tEvent ID : $($env:i_EventID)`tEvent Type : $($env:i_EventType)`tTime Range (Hours) : $($env:i_LogRange)"
write-output "----------------------------------`r`n"
write-output "----------------------------------"
write-output "TOTAL EVENTS : $($script:intTotal)"
write-output "----------------------------------"
write-output "EVENTS WITHIN PAST $($env:i_LogRange) HOURS : $($FilteredEvents.Count)"
$EventLogs = foreach ($Event in $FilteredEvents) {
  if ($script:hashEvents.containskey("$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)")) {
    if ($script:hashMessage.containskey("$($Event.Message)")) {
      $script:hashMessage["$($Event.Message)"].Occurences += 1
      $script:hashMessage["$($Event.Message)"].TimeCreated += "`r`n$($Event.TimeCreated)"
      #$script:hashEvents["$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)"].Occurences += 1
      #$script:hashEvents["$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)"].TimeCreated += "`r`n$($Event.TimeCreated)"
    } elseif (-not $script:hashMessage.containskey("$($Event.Message)")) {
      $script:hashDetails = @{
        TimeCreated      = [string]$Event.TimeCreated
        EventMessage     = $Event.Message
        Occurences       = 1
      }
      $script:hashMessage.add("$($Event.Message)", $script:hashDetails)
      $script:hashEvents.add("$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)", $script:hashMessage)
    }
    continue
  } elseif (-not $script:hashEvents.containskey("$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)")) {
    $script:hashDetails = @{
      TimeCreated      = [string]$Event.TimeCreated
      EventMessage     = $Event.Message
      Occurences       = 1
    }
    $script:hashMessage.add("$($Event.Message)", $script:hashDetails)
    $script:hashEvents.add("$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)", $script:hashMessage)
  }
}
#Stop script execution time calculation
StopClock
#DATTO OUTPUT
$script:diag += "`r`n`r`nDATTO OUTPUT :`r`n"
write-output "`r`nDATTO OUTPUT :" -foregroundcolor yellow
if ($FilteredEvents.Count -lt $env:i_EventThreshold) {
  $script:diag += "`r`n - Event Log : Healthy - No Source : $($env:i_EventSource) Events detected in LogName : $($env:i_EventLog)"
  write-output "`r`n - Event Log : Healthy - No Source : $($env:i_EventSource) Events detected in LogName : $($env:i_EventLog)" -foregroundcolor green
  write-DRRMAlert "Event Log : Healthy - No Source : $($env:i_EventSource) Events detected in LogName : $($env:i_EventLog)"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($FilteredEvents.Count -ge $env:i_EventThreshold) {
  [string[]]$arrHash = $script:hashEvents | out-string -stream
  $script:diag += "----------------------------------`r`n"
  $script:diag += "ALERT`r`n"
  $script:diag += "----------------------------------`r`n"
  $script:diag += "`r`nThe following Event Log Entries passed thresholds ($($env:i_EventThreshold) Events in $($env:i_LogRange) hours) :`r`n"
  $script:diag += $arrHash
  $script:diag += "`r`n"
  $script:diag += "OCCURENCES : $($script:hashMessage["$($Event.Message)"].Occurences)`r`n"
  $script:diag += "TIMESTAMPS :`r`n"
  write-output "----------------------------------"
  write-output "ALERT"
  write-output "----------------------------------"
  write-output "The following Event Log Entries passed thresholds ($($env:i_EventThreshold) Events in $($env:i_LogRange) hours) :" -foregroundcolor yellow
  write-output $arrHash -foregroundcolor red
  write-output "OCCURENCES : $($script:hashMessage["$($Event.Message)"].Occurences)" -foregroundcolor red
  write-output "TIMESTAMPS :" -foregroundcolor red
  foreach ($Value in $script:hashEvents["$($Event.ProviderName) - $($Event.Id) - $($Event.LevelDisplayName)"].keys) {
    $script:diag += "$($script:hashMessage[$Value].TimeCreated)`r`n"
    write-output "$($script:hashMessage[$Value].TimeCreated)" -foregroundcolor red
  }
  write-DRRMAlert "Event Log : Warning - $($FilteredEvents.Count) Source : $($env:i_EventSource) Events detected in LogName : $($env:i_EventLog)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------