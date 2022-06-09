#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  Param (
    [Parameter(Mandatory=$true)]$strHDR,
    [Parameter(Mandatory=$true)]$strCHG,
    [Parameter(Mandatory=$true)]$strVAL,
    [Parameter(Mandatory=$false)]$blnFORCE
  )
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
    write-host  "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRRMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRRMAlert

  function logERR($intSTG) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - CONFIG.INI NOT PRESENT, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT`r`n`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - CONFIG.INI NOT PRESENT, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_CONFIG - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
      3 {                                                         #'ERRRET'=3 - SPECIFIED 'VALUE' MIS-MATCH, NOT FORCING INJECT 'STRING', AND 'STRVAL'
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE"
      }
      4 {                                                         #'ERRRET'=4 - SPECIFIED 'HEADER' NOT FOUND, NOT FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
        $script:diag += "`r`n`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - SPECIFIED 'HEADER' NOT FOUND, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE`r`n"
        write-host "`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - SPECIFIED 'HEADER' NOT FOUND, 'FORCE' PARAMETER SET TO $($blnFORCE), NO MODIFICATIONS BEING MADE"
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
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_CONFIG`r`n"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_CONFIG"
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
if ((($null -eq $strHDR) -or ($strHDR -eq "")) -or
  (($null -eq $strCHG) -or ($strCHG -eq "")) -or
  (($null -eq $strVAL) -or ($strVAL -eq ""))) {                   #NOT ENOUGH ARGUMENTS, END SCRIPT
    logERR 2
}
if (($null -eq $blnFORCE) -or ($blnFORCE -eq "")) {
  $blnFORCE = $false
} elseif (($blnFORCE.tolower() -eq "true") -or ($blnFORCE.tolower() -eq "$true")) {
  $blnFORCE = $true
}
#PARSE CONFIG.INI FILE
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CURRENT CONFIG.INI`r`n"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - CURRENT CONFIG.INI"
foreach ($line in $objCFG) {                                      #CHECK CONFIG.INI LINE BY LINE
  $script:diag += "`t`t$($line)`r`n"
  write-host "`t`t$($line)"
  if ($line -eq $strHDR) {                                        #FOUND SPECIFIED 'HEADER' IN CONFIG.INI
    write-host "`t`tHEADER TARGET : $($strHDR)"
    write-host "`t`tHEADER MATCH : $($line)"
    $blnFND = $true
    $blnHDR = $true
  }
  if ($blnHDR -and ($line -match $strCHG)) {                      #STRING TO INJECT ALREADY IN CONFIG.INI
    write-host "`t`tSTRING TARGET : $($strCHG)"
    write-host "`t`tSTRING MATCH : $($line)"
    $blnINJ = $false
    $blnMOD = $false
    if ($line.split("=")[1] -eq $strVAL) {                        #PASSED VALUE 'STRVAL' MATCHES INTERNAL STRING VALUE
      $blnINJ = $false
      $blnMOD = $false
    } elseif ($line.split("=")[1] -ne $strVAL) {                  #PASSED VALUE 'STRVAL' DOES NOT MATCH INTERNAL STRING VALUE
      write-host "`t`tVALUE TARGET : $($strCHG)=$($strVAL)"
      write-host "`t`tVALUE MIS-MATCH : $($line)"
      $blnINJ = $true
      if (-not $blnFORCE) {
        $blnHDR = $false
        $blnMOD = $false
      } elseif ($blnFORCE) {
        $blnHDR = $false
        $blnMOD = $true
        $line = "$($strCHG)=$($strVAL)"
      }
    }
  }
  if (($blnHDR -and $blnMOD) -and 
    (($null -eq $line) -or ($line -eq ""))) {                     #STRING TO INJECT NOT FOUND, INJECT UNDER CURRENT 'HEADER'
      $blnHDR = $false
      $blnINJ = $true
      $blnMOD = $true
      $line = "$($strCHG)=$($strVAL)`r`n`r`n"
  }
  $arrCFG.add($line)
}
#REPLACE CONFIG.INI FILE
$objCFG = $null
$script:diag += "`r`nblnINJ : $($blnINJ)`r`n"
$script:diag += "blnHDR : $($blnHDR)`r`n"
$script:diag += "blnMOD : $($blnMOD)`r`n"
$script:diag += "blnFND : $($blnFND)`r`n"
$script:diag += "blnFORCE : $($blnFORCE)`r`n`r`n"
write-host "`r`nblnINJ : $($blnINJ)"
write-host "blnHDR : $($blnHDR)"
write-host "blnMOD : $($blnMOD)"
write-host "blnFND : $($blnFND)"
write-host "blnFORCE : $($blnFORCE)`r`n"
if ($blnINJ) {
  if (-not $blnMOD) {                                             #SPECIFIED 'VALUE' MIS-MATCH, NOT FORCING INJECT 'STRING', AND 'STRVAL'
    logERR 3
  } elseif ($blnMOD) {                                            #SPECIFIED 'HEADER' FOUND, INJECT 'STRING', AND 'STRVAL'
    $null | set-content $cfgPath -force
    $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
    write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI"
    foreach ($line in $arrCFG) {                                  #RE-BUILD CONFIG.INI LINE BY LINE
      $script:diag += "`t`t$($line)`r`n"
      write-host "`t`t$($line)"
      "$($line)" | add-content $cfgPath -force
    }
  }
}
if ((-not $blnFND) -and ( -not $blnFORCE)) {                      #SPECIFIED 'HEADER' NOT FOUND, NOT FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
  logERR 4
} elseif ((-not $blnFND) -and ($blnFORCE)) {                      #SPECIFIED 'HEADER' NOT FOUND, FORCING INJECT 'HEADER', 'STRING', AND 'STRVAL'
  $null | set-content $cfgPath -force
  $script:diag += "`r`n`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
  write-host "`r`n$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - NEW CONFIG.INI`r`n"
  foreach ($line in $arrCFG) {                                    #RE-BUILD CONFIG.INI LINE BY LINE
    $script:diag += "`t`t$($line)`r`n"
    write-host "`t`t$($line)"
    "$($line)" | add-content $cfgPath -force
  }
  $script:diag += "`r`n`t`t$($strHDR)`r`n`t`t$($strCHG)=$($strVAL)`r`n"
  write-host "`r`n`t`t$($strHDR)`r`n`t`t$($strCHG)=$($strVAL)"
  "`r`n$($strHDR)`r`n$($strCHG)=$($strVAL)`r`n" | add-content $cfgPath -force
}
#DATTO OUTPUT
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_CONFIG COMPLETE`r`n"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_CONFIG COMPLETE"
#Stop script execution time calculation
StopClock
if ($script:blnWARN) {
  write-DRRMAlert "MSP_Config : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "MSP_Config : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------