<#
    .SYNOPSIS
        Remove junk apps from windows such as mail
    .DESCRIPTION
        This script grabs all installed software and filters through it to remove junk apps. Examples of junk apps include mail, cortana, people, xbox.
        Copyright 2024 Cameron Day, Chris Bledsoe
#>
#region - DECLORATIONS
$script:diag                   = $null
$script:blnWARN                = $false
$script:blnBREAK               = $false
$script:arrInstalledSoftware   = Get-AppxPackage | Where {$_.Name -match "Microsoft"} | Select PackageFullName
$script:arrUninstalledSoftware = @()
$script:arrFailedToUnistall    = @()
$strLineSeparator              = "----------------------------------"
$script:arrJunkSoftware        = @(
  "Microsoft.GamingApp",
  "Microsoft.BingWeather",
  "Microsoft.BingNews",
  "Microsoft.Xbox.TCUI",
  "Microsoft.XboxGameOverlay",
  "Microsoft.XboxSpeechToTextOverlay",
  "Microsoft.XboxGameCallableUI",
  "Microsoft.XboxIdentityProvider",
  "Microsoft.Todos",
  "Microsoft.Getstarted",
  "Microsoft.WindowsMaps",
  "Microsoft.MicrosoftSolitaireCollection",
  "Microsoft.WindowsFeedbackHub",
  "Microsoft.GetHelp",
  "MicrosoftTeams",
  "Microsoft.windowscommunicationsapps",
  "Microsoft.People",
  "Microsoft.ZuneVideo",
  "Microsoft.ZuneMusic",
  "Clipchamp.Clipchamp",
  "MicrosoftCorporationII.QuickAssist",
  "Microsoft.Windows.DevHome"
)
#endregion - DECLORATIONS

#region - FUNCTIONS

function write-DRMMDiag ($messages) {
  write-output "<-Start Diagnostic->"
  foreach ($message in $messages) { $message }
  write-output "<-End Diagnostic->"
} ## write-DRMMDiag

function write-DRMMAlert ($message) {
  write-output "<-Start Result->"
  write-output "Alert=$($message)"
  write-output "<-End Result->"
} ## write-DRMMAlert

function StopClock {
  #Stop script execution time calculation
  $script:sw.Stop()
  $Days = $sw.Elapsed.Days
  $Hours = $sw.Elapsed.Hours
  $Minutes = $sw.Elapsed.Minutes
  $Seconds = $sw.Elapsed.Seconds
  $Milliseconds = $sw.Elapsed.Milliseconds
  $script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
  write-output "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  $script:diag += "`r`n`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
}

function logERR ($intSTG, $strModule, $strErr) {
  $script:blnWARN = $true
  #CUSTOM ERROR CODES
  switch ($intSTG) {
    1 {
      #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - NO ARGUMENTS PASSED, END SCRIPT`r`n"
    }
    2 {
      #'ERRRET'=2 - END SCRIPT
      $script:blnBREAK = $true
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - ($($strModule)) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - ($($strModule)) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
    }
    3 {
      #'ERRRET'=3
      $script:blnWARN = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
    default {
      #'ERRRET'=4+
      $script:blnBREAK = $false
      $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - $($strModule) :"
      $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
      write-output "$($strLineSeparator)`r`n$($(get-date)) - Remove-JunkApps - $($strModule) :"
      write-output "$($strLineSeparator)`r`n`t$($strErr)"
    }
  }
}

function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
  if (-not (test-path -path "C:\temp")) { new-item -path "C:\temp" -itemtype directory -force }
  if (-not (test-path -path "C:\IT")) { new-item -path "C:\IT" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Log")) { new-item -path "C:\IT\Log" -itemtype directory -force }
  if (-not (test-path -path "C:\IT\Scripts")) { new-item -path "C:\IT\Scripts" -itemtype directory -force }
}

#endregion - FUNCTIONS

#region - SCRIPT START

$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
logERR 3 "Script Start" "Begin Script : $($ScrptStartTime)"
dir-Check
if (($script:arrInstalledSoftware -eq "") -or ($null -eq $script:arrInstalledSoftware)) {
  logERR 2 "Script Start" "Installed software not collected, please run script again!"
}
$varArr = @()
foreach ($app in $script:arrJunkSoftware) { $varArr += $script:arrInstalledSoftware | where {$_.PackageFullName -like "*$($app)*"} }
foreach ($package in $varArr) { 
  Try {
    logERR 3 "Uninstall Stage" "Attempting to uninstall $($package.PackageFullName)." 
    if ($package.PackageFullName -like "Microsoft.XboxIdentityProvider") {
      Remove-AppPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
      $script:arrUninstalledSoftware += "$($package.PackageFullName)`r`n`t"
    } else {
      Remove-AppPackage -Package $package.PackageFullName -ErrorAction Stop
      $script:arrUninstalledSoftware += "$($package.PackageFullName)`r`n`t"
    }
  } Catch {
    $err = "$($package.PackageFullName) failed to uninstall"
    logERR 3 "Uninstall Stage" "$($err)"
    $script:arrFailedToUnistall += "$($package.PackageFullName)`r`n`t"
  }
}

$arrGameBarService = Get-Service | where {$_.Name -match "BcastDVRUserService"}
Stop-Service $arrGameBarService.Name 
& "sc.exe delete $($arrGameBarService.Name)" #Manually delete service bar

$script:finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    $enddiag = "Execution Successful : $($script:finish)`r`n$($strLineSeparator)`r`n"
    logERR 3 "END" "$($enddiag)"
    logERR 3 "Software Uninstalled" "$($script:arrUninstalledSoftware)"
    write-DRMMAlert "$($script:mode) : Healthy : $($enddiag) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    $enddiag = "Execution Completed with Warnings : $($script:finish)`r`n$($strLineSeparator)`r`n"
    logERR 3 "END" "$($enddiag)"
    write-DRMMAlert "$($script:mode) : Execution Completed with Warnings : $($enddiag) : $($script:finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  $enddiag += "Execution Failed : $($script:finish)`r`n$($strLineSeparator)"
  logERR 4 "END" "$($enddiag)"
  write-DRMMAlert "$($script:mode) : Failure : Diagnostics : $($enddiag) :$($script:finish)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}

#endregion - SCRIPT START