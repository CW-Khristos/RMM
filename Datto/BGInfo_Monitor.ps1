# If you are reading this, you have copied the Component successfully,
# probably for the purposes of attaching your own configuration file.
# Near the bottom of this page, attach your .bgi file to the Component
# and then save the Component with a new name. The script will identify
# the presence of the file and alter the startup routines to use it.
# ----------------------------------------------------------------------
# BGInfo installer/implanter :: build 17/seagull december 2020 :: thanks to michael mccool

# Modifications : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  $script:diag = $null
  $script:blnWARN = $false
  $script:blnBREAK = $false
  $logPath = "C:\IT\Log\BG_Info"
  $strLineSeparator = "----------------------------------"
  $bgKeys = @(
    "HKCU:\Software\Winternals\BGInfo",
    "HKLM:\Software\Winternals\BGInfo"
  )
  $cfgDefault = "C:\IT\BGInfo\default.bgi"
  $cmdScript = "C:\IT\Scripts\BGILaunch.cmd"
  $prevScript = "$($env:ProgramData)\Microsoft\Windows\Start Menu\Programs\StartUp\BGILaunch.cmd"
  $newLink = "$($env:ProgramData)\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo - Shortcut.lnk"
  $allLink = "$($env:ALLUSERSPROFILE)\Microsoft\Windows\Start Menu\Programs\StartUp\BGInfo - Shortcut.lnk"
  #Set Wallpaper Code
  $wallpaper = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
  $wpCode = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
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
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BG_Info - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BG_Info - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BG_Info - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BG_Info - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BG_Info - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BG_Info - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - BG_Info - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - BG_Info - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

  function Set-Wallpaper ($MyWallpaper) {
    add-type $wpCode 
    [Win32.Wallpaper]::SetWallpaper($MyWallpaper)
  }

  function New-Shortcut {
    [CmdletBinding()]  
    Param (   
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]$TargetPath,                # the path to the executable
      # the rest is all optional
      [string]$ShortcutPath, # = (Join-Path -Path ([Environment]::GetFolderPath("Desktop")) -ChildPath 'New Shortcut.lnk'),
      [string[]]$Arguments = $null,       # a string or string array holding the optional arguments.
      #[string[]]$HotKey = $null,          # a string like "CTRL+SHIFT+F" or an array like 'CTRL','SHIFT','F'
      #[string]$WorkingDirectory = $null,  
      #[string]$Description = $null,
      #[string]$IconLocation = $null,      # a string like "notepad.exe, 0"
      #[ValidateSet('Default','Maximized','Minimized')]
      [string]$WindowStyle = 'Minimized',
      [switch]$RunAsAdmin
    ) 
    switch ($WindowStyle) {
      'Default'   { $style = 1; break }
      'Maximized' { $style = 3; break }
      'Minimized' { $style = 7}
    }
    $WshShell = New-Object -ComObject WScript.Shell
    # create a new shortcut
    $shortcut             = $WshShell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath  = $TargetPath
    $shortcut.WindowStyle = $style
    if ($Arguments)        { $shortcut.Arguments = $Arguments -join ' ' }
    if ($HotKey)           { $shortcut.Hotkey = ($HotKey -join '+').ToUpperInvariant() }
    if ($IconLocation)     { $shortcut.IconLocation = $IconLocation }
    if ($Description)      { $shortcut.Description = $Description }
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    # save the link file
    $shortcut.Save()
    if ($RunAsAdmin) {
      # read the shortcut file we have just created as [byte[]]
      [byte[]]$bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
      # $bytes[21] = 0x22      # set byte no. 21 to ASCII value 34
      $bytes[21] = $bytes[21] -bor 0x20 #s et byte 21 bit 6 (0x20) ON
      [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
    }

    # clean up the COM objects
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shortcut) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }

  function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {
      new-item -path "C:\temp" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT")) {
      new-item -path "C:\IT" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Log")) {
      new-item -path "C:\IT\Log" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Scripts")) {
      new-item -path "C:\IT\Scripts" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\BGInfo")) {
      new-item -path "C:\IT\BGInfo" -itemtype directory -force | out-string
    }
  }

  function write-Script ($destFile, $shortcut) {
    #furnish a quick CMD script
    set-content "$($destFile)" -value '@echo off'
    add-content "$($destFile)" -value 'echo Please wait -- Configuring wallpaper'
    add-content "$($destFile)" -value "C:\IT\BGInfo\bginfo$([intptr]::Size).exe `"$($cfgDefault)`" /silent /nolicprompt /timer:0"
    add-content "$($destFile)" -value "ping -n 5 127.0.0.1 > nul"
    #put shortcuts into startup folders
    if ($shortcut) {
      New-Shortcut "$($destFile)" "$($newLink)"
      New-Shortcut "$($destFile)" "$($allLink)"
    }
    #remove previous CMD scripts from startup folder
    if (test-path -path "$($prevScript)" -pathtype leaf) {remove-item "$($prevScript)" -force}
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    # install the executable somewhere we can bank on its presence
    move-item bginfo4.exe "C:\IT\BGInfo" -force
    move-item bginfo8.exe "C:\IT\BGInfo" -force
    # check for BGIs
    if (!(test-path *.bgi)) {
      $timestanp = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
      $mondiag = "- ERROR: There needs to be at least one .bgi file for the Component to work`r`n"
      $mondiag += "  Execution cannot continue. Exiting`r`n"
      $mondiag += "`r`n`r`nExecution Failed : $($timestanp)"
      logERR 2 "BG_Info" "$($mondiag)"
    } else {
      if (test-path *.bgi -exclude default.bgi) {
        $varArgs=(ls *.bgi -Exclude default.bgi | Select-Object -First 1).Name
        $varArgs=`'$varArgs`'
      } else {
        $varArgs='default.bgi'
      }
      move-item $varArgs "C:\IT\BGInfo" -force
    }
    #furnish a quick CMD script
    write-Script "$($cmdScript)" $true
    # inform the user
    write-host "- BGInfo has been installed and configured to run on Startup"
    write-host "  Endpoints will need to be rebooted for changes to take effect"
    $script:diag += "- BGInfo has been installed and configured to run on Startup`r`n"
    $script:diag += "  Endpoints will need to be rebooted for changes to take effect`r`n"
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "C:\IT\BGInfo"
    if (-not $result) {                 #PATH DOES NOT EXIST, DEPLOY BGINFO
      run-Deploy
    } elseif ($result) {                #PATH EXISTS
      #CHECK STARTUP CMDSCRIPT
      $result = test-path -path "$($cmdScript)"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY STRATUP SCRIPT
        #furnish a quick CMD script
        write-Script "$($cmdScript)" $true
      } elseif ($result) {              #FILE EXISTS
        $scrCompare = "C:\IT\BGInfo\compare.cmd"
        write-Script "$($scrCompare)" $false
        #COMPARE STRATUP SCRIPT FILE AS 'COMPARE.CMD' TO 'BGILAUNCH.CMD' FILE IN PATH
        if (Compare-Object -ReferenceObject $(Get-Content $cmdScript) -DifferenceObject $(Get-Content $scrCompare)) {
          "Files are different"
        } else {
          "Files are same"
        }
      }
      #CHECK BGINFO CONFIGURATION FILE 'DEFAULT.BGI'
      $result = test-path -path "$($cfgDefault)"
      if (-not $result) {               #FILE DOES NOT EXIST, DEPLOY COMPONENT ATTACHED 'DEFAULT.BGI'
        move-item default.bgi "$($cfgDefault)" -force
      } elseif ($result) {              #FILE EXISTS
        $cfgCompare = "C:\IT\BGInfo\compare.bgi"
        move-item default.bgi "$($cfgCompare)" -force
        #COMPARE COMPONENT ATTACHED 'DEFAULT.BGI' FILE AS 'COMPARE.BGI' TO 'DEFAULT.BGI' FILE IN PATH
        if (Compare-Object -ReferenceObject $(Get-Content $cfgDefault) -DifferenceObject $(Get-Content $cfgCompare)) {
          "Files are different"
          move-item default.bgi "$($cfgDefault)" -force
        } else {
          "Files are same"
        }
      }
      #CHECK IF BGINFO IS ALREADY RUNNING
      $process = tasklist | findstr /B "bginfo"
      if ($process) {                   #BGINFO ALREADY RUNNING
        $running = $true
      } elseif (-not $process) {        #BGINFO NOT RUNNING
        $running = $false
        $timestanp = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
        $mondiag = "`r`n`r`nExecution Failed : $($timestanp)"
        logERR 2 "BG_Info" "$($mondiag)"
      }
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      
    }
    try {
      run-Deploy
    } catch {
      
    }
  }

  function run-Remove () {
    #Remove Registry Keys
    foreach ($key in $bgKeys) {
      write-host "Checking Registry for Key : $($key)"
      $script:diag += "Checking Registry for Key : $($key)`r`n"
      $bgKey = get-itemproperty -path "$($key)" -erroraction silentlycontinue
      if ($bgKey) {
        write-host "Found Key : $($key) : REMOVING"
        $script:diag += "Found Key : $($key) : REMOVING`r`n"
        remove-item -path "$($key)" -recurse -force -erroraction stop
      } elseif (-not $bgKey) {
        write-host "Key : $($key) : NOT PRESENT"
        $script:diag += "Key : $($key) : NOT PRESENT`r`n"
      }
    }
    #CHECK IF BGINFO IS ALREADY RUNNING
    $process = tasklist | findstr /B "bginfo"
    if ($process) {                   #BGINFO ALREADY RUNNING
      $running = $true
      $result = taskkill /IM "bginfo*" /F
    } elseif (-not $process) {        #BGINFO NOT RUNNING
      $running = $false
    }
    #REMOVE FILES
    write-host "Removing BGInfo Files"
    $script:diag += "Removing BGInfo Files`r`n"
    try {
      remove-item -path "C:\IT\BGInfo" -recurse -force -erroraction stop
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : C:\IT\BGInfo"
        $script:diag += "NOT PRESENT : C:\IT\BGInfo"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      }
    }
    try {
      remove-item -path "$($newLink)" -force -erroraction stop
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : $($newLink)"
        $script:diag += "NOT PRESENT : $($newLink)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      }
    }
    try {
      remove-item -path "$($allLink)" -force -erroraction stop
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        write-host "NOT PRESENT : $($allLink)"
        $script:diag += "NOT PRESENT : $($allLink)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
        $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      }
    }
    #SET DEFAULT WALLPAPER
    try {
      Set-Wallpaper("$($wallpaper)") -erroraction stop
    } catch {
      write-host "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
      $script:diag += "ERROR`r`n$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)"
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
dir-Check
if ($env:strTask -eq "DEPLOY") {
  write-host "Install and configure BGInfo Files and Startup`r`n$($strLineSeparator)"
  $script:diag += "Install and configure BGInfo Files and Startup`r`n$($strLineSeparator)`r`n"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "MONITOR") {
  write-host "Monitoring BGInfo Files and Startup`r`n$($strLineSeparator)"
  $script:diag += "Monitoring BGInfo Files and Startup`r`n$($strLineSeparator)`r`n"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "UPGRADE") {
  write-host "Replacing BGInfo Files and Startup`r`n$($strLineSeparator)"
  $script:diag += "Replacing BGInfo Files and Startup`r`n$($strLineSeparator)`r`n"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    
  }
} elseif ($env:strTask -eq "REMOVE") {
  write-host "Removing BGInfo Files and Startup`r`n$($strLineSeparator)"
  $script:diag += "Removing BGInfo Files and Startup`r`n$($strLineSeparator)`r`n"
  try {
    run-Remove -erroraction stop
    
  } catch {
    
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
if (-not $script:blnBREAK) {
  if (-not $script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "`r`n`r`nExecution Successful : $($finish)"
    logERR 3 "BG_Info" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "BG_Info : Successful : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 0
  } elseif ($script:blnWARN) {
    #WRITE TO LOGFILE
    $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
    $enddiag = "`r`n`r`nExecution Completed with Warnings : $($finish)"
    logERR 3 "BG_Info" "$($enddiag)"
    "$($script:diag)" | add-content $logPath -force
    write-DRMMAlert "BG_Info : Warning : Diagnostics - $($logPath) : $($finish)"
    write-DRMMDiag "$($script:diag)"
    exit 1
  }
} elseif ($script:blnBREAK) {
  #WRITE TO LOGFILE
  $finish = "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))"
  $enddiag = "`r`n`r`nExecution Failed : $($finish)"
  logERR 4 "BG_Info" "$($enddiag)"
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "BG_Info : Failure : Diagnostics - $($logPath) : $($finish)"
  write-DRMMDiag "$($script:diag)"
  $script:diag = $null
  exit 1
}
#END SCRIPT
#------------