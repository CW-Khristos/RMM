#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$strHDR,
  #  [Parameter(Mandatory=$true)]$strCHG,
  #  [Parameter(Mandatory=$true)]$strVAL,
  #  [Parameter(Mandatory=$false)]$blnFORCE
  #)
  $blnFND = $false
  $blnHDR = $false
  $blnINJ = $false
  $blnMOD = $true
  $script:diag = $null
  $arrCFG = [System.Collections.ArrayList]@()
  $cfgPath = "C:\Program Files\Backup Manager\config.ini"
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-output  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-output "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-output "<-Start Result->"
    write-output "Alert=$($message)"
    write-output "<-End Result->"
  } ## write-DRMMAlert

  function logERR($intSTG) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - CONFIG.INI NOT PRESENT, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT`r`n`r`n"
        write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      3 {                                                         #'ERRRET'=3 - SPECIFIED 'VALUE' MIS-MATCH, NOT FORCING INJECT 'STRING', AND 'STRVAL'
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE`r`n"
        write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE"
      }
      4 {                                                         #'ERRRET'=4 - SPECIFIED 'HEADER' NOT FOUND, NOT FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
        $script:diag += "`r`n`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - SPECIFIED 'HEADER' NOT FOUND, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE`r`n"
        write-output "`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - SPECIFIED 'HEADER' NOT FOUND, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE"
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
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_CONFIG`r`n"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_CONFIG"
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Log")) {
  new-item -path "C:\IT\Log" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
#MSP BACKUP MANAGER CONFIG.INI FILE
if (test-path -path "$($cfgPath)") {                              #CONFIG.INI PRESENT
  $objCFG = get-content "$($cfgPath)"
} elseif (-not (test-path -path "$($cfgPath)")) {                 #CONFIG.INI NOT PRESENT, END SCRIPT
  logERR 1
}
#INPUT VALIDATION
if ((($null -eq $env:strHDR) -or ($env:strHDR -eq "")) -or
  (($null -eq $env:strCHG) -or ($env:strCHG -eq "")) -or
  (($null -eq $env:strVAL) -or ($env:strVAL -eq ""))) {           #NOT ENOUGH ARGUMENTS, END SCRIPT
    logERR 2
}
if (($null -eq $env:blnFORCE) -or ($env:blnFORCE -eq "")) {
  $env:blnFORCE = $false
} elseif (($env:blnFORCE.tolower() -eq "true") -or ($env:blnFORCE.tolower() -eq "$true")) {
  $env:blnFORCE = $true
}
#PARSE CONFIG.INI FILE
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CURRENT CONFIG.INI`r`n"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CURRENT CONFIG.INI"
foreach ($line in $objCFG) {                                      #CHECK CONFIG.INI LINE BY LINE
  $script:diag += "`t`t$($line)`r`n"
  write-output "`t`t$($line)"
  if ($line -eq $env:strHDR) {                                    #FOUND SPECIFIED 'HEADER' IN CONFIG.INI
    write-output "`t`tHEADER TARGET : $($env:strHDR)"
    write-output "`t`tHEADER MATCH : $($line)"
    $blnFND = $true
    $blnHDR = $true
  }
  if ($blnHDR -and ($line -match $env:strCHG)) {                  #STRING TO INJECT ALREADY IN CONFIG.INI
    write-output "`t`tSTRING TARGET : $($env:strCHG)"
    write-output "`t`tSTRING MATCH : $($line)"
    $blnINJ = $false
    $blnMOD = $false
    if ($line.split("=")[1] -eq $env:strVAL) {                    #PASSED VALUE 'STRVAL' MATCHES INTERNAL STRING VALUE
      $blnINJ = $false
      $blnMOD = $false
    } elseif ($line.split("=")[1] -ne $env:strVAL) {              #PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE
      write-output "`t`tVALUE TARGET : $($env:strCHG)=$($env:strVAL)"
      write-output "`t`tVALUE MIS-MATCH : $($line)"
      $blnINJ = $true
      if (-not $env:blnFORCE) {
        $blnHDR = $false
        $blnMOD = $false
      } elseif ($env:blnFORCE) {
        $blnHDR = $false
        $blnMOD = $true
        $line = "$($env:strCHG)=$($env:strVAL)"
      }
    }
  }
  if (($blnHDR -and $blnMOD) -and 
    (($null -eq $line) -or ($line -eq ""))) {                     #STRING TO INJECT NOT FOUND, INJECT UNDER CURRENT 'HEADER'
      $blnHDR = $false
      $blnINJ = $true
      $blnMOD = $true
      $line = "$($env:strCHG)=$($env:strVAL)`r`n`r`n"
  }
  $arrCFG.add($line)
}
#REPLACE CONFIG.INI FILE
$objCFG = $null
$script:diag += "`r`nblnINJ : $($blnINJ)`r`n"
$script:diag += "blnHDR : $($blnHDR)`r`n"
$script:diag += "blnMOD : $($blnMOD)`r`n"
$script:diag += "blnFND : $($blnFND)`r`n"
$script:diag += "blnFORCE : $($env:blnFORCE)`r`n`r`n"
write-output "`r`nblnINJ : $($blnINJ)"
write-output "blnHDR : $($blnHDR)"
write-output "blnMOD : $($blnMOD)"
write-output "blnFND : $($blnFND)"
write-output "blnFORCE : $($env:blnFORCE)`r`n"
if ($blnINJ) {
  if (-not $blnMOD) {                                             #SPECIFIED 'VALUE' MIS-MATCH, NOT FORCING INJECT 'STRING', AND 'STRVAL'
    logERR 3
  } elseif ($blnMOD) {                                            #SPECIFIED 'HEADER' FOUND, INJECT 'STRING', AND 'STRVAL'
    $null | set-content $cfgPath -force
    $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
    write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI"
    foreach ($line in $arrCFG) {                                  #RE-BUILD CONFIG.INI LINE BY LINE
      $script:diag += "`t`t$($line)`r`n"
      write-output "`t`t$($line)"
      "$($line)" | add-content $cfgPath -force
    }
  }
}
if ((-not $blnFND) -and ( -not $blnFORCE)) {                      #SPECIFIED 'HEADER' NOT FOUND, NOT FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
  logERR 4
} elseif ((-not $blnFND) -and ($blnFORCE)) {                      #SPECIFIED 'HEADER' NOT FOUND, FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
  $null | set-content $cfgPath -force
  $script:diag += "`r`n`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
  write-output "`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
  foreach ($line in $arrCFG) {                                    #RE-BUILD CONFIG.INI LINE BY LINE
    $script:diag += "`t`t$($line)`r`n"
    write-output "`t`t$($line)"
    "$($line)" | add-content $cfgPath -force
  }
  $script:diag += "`r`n`t`t$($env:strHDR)`r`n`t`t$($env:strCHG)=$($env:strVAL)`r`n"
  write-output "`r`n`t`t$($env:strHDR)`r`n`t`t$($env:strCHG)=$($env:strVAL)"
  "`r`n$($env:strHDR)`r`n$($env:strCHG)=$($env:strVAL)`r`n" | add-content $cfgPath -force
}
#DATTO OUTPUT
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_CONFIG COMPLETE`r`n"
write-output "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_CONFIG COMPLETE"
#Stop script execution time calculation
StopClock
if ($script:blnWARN) {
  write-DRMMAlert "MSP_Config : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRMMAlert "MSP_Config : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------