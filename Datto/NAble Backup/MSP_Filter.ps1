#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:var' TO '$var' TO UTILIZE IN CLI
  Param (
    [Parameter(Mandatory=$true)]$strOPT
  #  [Parameter(Mandatory=$true)]$strUSR,
  #  [Parameter(Mandatory=$true)]$strICL,
  #  [Parameter(Mandatory=$false)]$strFILTER
  )
  $script:diag = $null
  $logPath = "C:\IT\Log\MSP_Filter"
  $cliPath = "C:\Program Files\Backup Manager\clienttool.exe"
  #USER AND USER FOLDER ARRAYS
  $objFOL = $null
  $arrFOL = [System.Collections.ArrayList]@()
  #USER FOLDER AND SUB-FOLDER ARRAYS
  $objUFOL = $null
  $arrUFOL = [System.Collections.ArrayList]@()
  #UNNEEDED / TO EXCLUDE USER ACCOUNTS
  $arrEXCL = [System.Collections.ArrayList]@(
    "nable"
  )
  #PROTECTED USER ACCOUNTS
  $arrPUSR = [System.Collections.ArrayList]@(
    "MSSQL",
    "Public",
    "Default",
    "Default.migrated"
  )
  #PROTECTED EXT / FILES / DIRECTORIES
  $arrPFOL = [System.Collections.ArrayList]@(
    ".PST",
    "Outlook\Roamcache"
  )
  #APPDATA FILES / FOLDERS
  $arrAPP = [System.Collections.ArrayList]@(
    "\AppData\Local\CrashDumps",
    "\AppData\Local\D3DSCache",
    "\AppData\Local\Google\Chrome\User Data\~",
    "\AppData\Local\Google\Chrome\User Data\Crashpad",
    "\AppData\Local\Google\Chrome\User Data\Default\Application Cache",
    "\AppData\Local\Google\Chrome\User Data\Default\Cache",
    "\AppData\Local\Google\Chrome\User Data\Default\Code Cache",
    "\AppData\Local\Google\Chrome\User Data\Default\GPUCache",
    "\AppData\Local\Google\Chrome\User Data\FontLookupTableCache",
    "\AppData\Local\Google\Chrome\User Data\ShaderCache",
    "\AppData\Local\Google\Chrome\User Data\PnaclTranslationCache",
    "\AppData\Local\Google\Chrome\User Data\Default\Service Worker\CacheStorage",
    "\AppData\Local\Google\Chrome\User Data\Default\Service Worker\ScriptCache",
    "\AppData\Local\Google\Chrome\User Data\SwReporter",
    "\AppData\Local\Google\CrashReports",
    "\AppData\Local\Google\Software Reporter Tool",
    "\AppData\Local\GWX",
    "\AppData\Local\Microsoft\Feeds Cache",
    "\AppData\Local\Microsoft\FontCache",
    "\AppData\Local\Microsoft\SquirrelTemp",
    "\AppData\Local\Microsoft\Terminal Server Client\Cache",
    "\AppData\Local\Microsoft\Windows\ActionCenterCache",
    "\AppData\Local\Microsoft\Windows\AppCache",
    "\AppData\Local\Microsoft\Windows\Caches",
    "\AppData\Local\Microsoft\Windows\Explorer\IconCacheToDelete",
    "\AppData\Local\Microsoft\Windows\IECompatCache",
    "\AppData\Local\Microsoft\Windows\IECompatUaCache",
    "\AppData\Local\Microsoft\Windows\INetCache",
    "\AppData\Local\Microsoft\Windows\PPBCompatCache",
    "\AppData\Local\Microsoft\Windows\PPBCompatUaCache",
    "\AppData\Local\Microsoft\Windows\PRICache",
    "\AppData\Local\Microsoft\Windows\SchCache",
    "\AppData\Local\Microsoft\Windows\WER",
    "\AppData\Local\Microsoft\Windows\WebCache",
    "\AppData\Local\Mozilla",
    "\AppData\Local\SquirrelTemp",
    "\AppData\Local\Temp",
    "\AppData\Local\IconCache.db",
    "\AppData\Local\Microsoft\Outlook\*.ost",
    "\AppData\Local\Microsoft\Outlook\*.tmp",
    "\AppData\Local\Microsoft\Windows\Explorer\iconcache*.db",
    "\AppData\Local\Microsoft\Windows\Explorer\thumbcache*.db",
    "\AppData\Local\MicrosoftEdge\SharedCacheContainers",
    "\AppData\Local\Microsoft\Windows\Explorer\IconCacheToDelete",
    "\AppData\Local\Microsoft\Edge\User Data\~",
    "\AppData\Local\Microsoft\Edge\User Data\Crashpad",
    "\AppData\Local\Microsoft\Edge\User Data\Default\Application Cache",
    "\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
    "\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
    "\AppData\Local\Microsoft\Edge\User Data\Default\GPUCache",
    "\AppData\Local\Microsoft\Edge\User Data\FontLookupTableCache",
    "\AppData\Local\Microsoft\Edge\User Data\ShaderCache",
    "\AppData\Local\Microsoft\Edge\User Data\PnaclTranslationCache",
    "\AppData\Local\Microsoft\Edge\User Data\SwReporter",
    "\AppData\Local\Microsoft\Edge\CrashReports",
    "\AppData\Local\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage",
    "\AppData\Local\Microsoft\Edge\User Data\Default\Service Worker\ScriptCache",
    "\AppData\Local\Packages"
  )
  #GOOGLE CHROME / MICROSOFT EDGE 'PROFILE' EXCLUSIONS
  #\AppData\Local\~\~\User Data\Profile #\"
  $arrPROF = [System.Collections.ArrayList]@(
    "\Application Cache",
    "\Cache",
    "\Code Cache",
    "\GPUCache",
    "\Service Worker\CacheStorage",
    "\Service Worker\ScriptCache"
  )
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

  function logERR ($intSTG) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      0 {                                                         #'ERRRET'=0 - CLIENTTOOL CHECK PASSED
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - CLIENTTOOL CHECK PASSED`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - CLIENTTOOL CHECK PASSED"
      }
      1 {                                                         #'ERRRET'=1 - CONFIG.INI NOT PRESENT, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - CONFIG.INI NOT PRESENT, END SCRIPT`r`n`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - CONFIG.INI NOT PRESENT, END SCRIPT`r`n"
      }
      2 {                                                         #'ERRRET'=2 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss'))`t - MSP_FILTER - NO ARGUMENTS PASSED, END SCRIPT`r`n"
      }
    }
  }

  function chkSFOL ($strSFOL) {
    #CHECK EACH 'C:\USERS\<USERNAME>' SUB-FOLDER
    $blnFND = false
    if (($null -ne $strSFOL) -and ($strSFOL -ne "")) {
      #ENUMERATE THROUGH AND MAKE SURE THIS ISN'T ONE OF THE 'PROTECTED' EXT / FILES / DIRECTORIES
      foreach ($pFOL in $arrPFOL) {
        $blnFND = $false
        if (($null -ne $pFOL) -and ($pFOL -ne "")) {
          # 'PRTOTECTED' EXT / FILES / DIRECTORIES 'ARRPFOL' FOUND IN FOLDER PATH
          if ($strSFOL.tolower() -match $pFOL.tolower()) {
            #objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & arrPFOL(intPCOL)
            #objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "PROTECTED : " & arrPFOL(intPCOL)
            #PROCEED WITH INCLUDING ENTIRE USER DIRECTORY
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strSFOL)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strSFOL)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($strSFOL)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
            start-sleep -milliseconds 100
            #MARK 'PROTECTED'
            $blnFND = true
            break
          }
        }
        #A 'UNNEEDED / TO EXCLUDE' USER ACCOUNT WAS PASSED TO 'STRUSR'
        #if (wscript.arguments.count > 0) then
        #  '' PASSED 'PRTOTECTED' USER ACCOUNT 'ARREXCL'
        #  if (instr(1, lcase(strSFOL), lcase(objARG.item(0)))) then
        #    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "UNNEEDED / TO EXCLUDE : " & objARG.item(0)
        #    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "UNNEEDED / TO EXCLUDE : " & objARG.item(0)
        #    ''MARK 'UNNEEDED / TO EXCLUDE'
        #    blnFND = true
        #    exit for
        #  end if          
        #end if
      }
      #NO MATCH TO 'PROTECTED' EXT / FILES / DIRECTORIES
      if (-not $blnFND) {
        #OUTLOOK OST / TMP  AND ICONCACHE / THUMBCACHE EXCLUSIONS
        if ($strSFOL -like '`*') {
          $strTMP = $null
          $arrTMP = $strSFOL.split("\")
          foreach ($chunk in $arrTMP) {
            $strTMP += "$($chunk)\"
          }
          $colSFIL = Get-ChildItem -Path "$($strTMP)" -attributes !Directory -Force -ErrorAction SilentlyContinue
          foreach ($subFIL in $colSFIL) {
            if ($subFIL.fullname.tolower() -match $strSFOL.split("*")[0].tolower()) {
              if ($subFIL.fullname.tolower() -match $strSFOL.split("*")[1].tolower()) {
                #objOUT.write vbnewline & "FILE : " & lcase(subFIL.path)
                #objOUT.write vbnewline & "MATCH : " & lcase(split(strSFOL, "*")(0))
                #objOUT.write vbnewline & "MATCH : " & lcase(split(strSFOL, "*")(1))
                #EXCLUDE FOLDER / FILE
                $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subFIL.fullname)`"`r`n"
                write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subFIL.fullname)`""
                $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($subFIL.fullname)`""
                $script:diag += "`t`t`t - $($output)`r`n"
                write-host "`t`t`t - $($output)"
                start-sleep -milliseconds 100
              }
            }
            start-sleep -milliseconds 100
          }
          $strTMP = $null
          $colSFIL = $null
          $subFIL = $null
        } elseif ($strSFOL -like "~") {
          #GOOGLE CHROME / MICROSOFT EDGE 'PROFILE' EXCLUSIONS
          #USE TO CHECK FURTHER SUB-FOLDERS / FILES
          $colSFOL = get-childitem -path $strSFOL.substring(0, $strSFOL.length - 1) -attributes Directory -Force -ErrorAction SilentlyContinue
          foreach ($subSFOL in $colSFOL) {
            if ($subSFOL.fullname -match "Profile ") {
              foreach ($item in $arrPROF) {
                #EXCLUDE FOLDER / FILE
                $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subSFOL.fullname)\$($item)`"`r`n"
                write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subSFOL.fullname)\$($item)`""
                $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($subSFOL.fullname)\$($item)`""
                $script:diag += "`t`t`t - $($output)`r`n"
                write-host "`t`t`t - $($output)"
                start-sleep -milliseconds 100
              }
            }
          }
          $colSFOL = $null
        } elseif ($strSFOL -notlike '`*') {
          #EXCLUDE FOLDER / FILE
          $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strSFOL)`"`r`n"
          write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strSFOL)`""
          $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($strSFOL)`""
          $script:diag += "`t`t`t - $($output)`r`n"
          write-host "`t`t`t - $($output)"
          start-sleep -milliseconds 100
        }
      }
    }
    #USE TO CHECK FURTHER SUB-FOLDERS / FILES
    #set objSFOL = objFSO.getfolder(strSFOL)
    #set colSFOL = objSFOL.subfolders
    #for each subSFOL in colSFOL
    #  call chkSFOL(subSFOL.path)
    #next
    #set colSFOL = nothing
    #set objSFOL = nothing
  }
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
#Start script execution time calculation
$ScrptStartTime = (Get-Date).ToString('dd-MM-yyyy hh:mm:ss')
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_FILTER`r`n"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - EXECUTING MSP_FILTER"
#REMOVE PREVIOUS LOGFILE
if (test-path -path "$($logPath)") {
  remove-item -path "$($logPath)" -force
}
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
#CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (test-path -path "$($cliPath)" -pathtype leaf) {
  LOGERR 0                                              #CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
} elseif (-not (test-path -path "$($cliPath)" -pathtype leaf)) {
  LOGERR 1                                              #CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
}
switch ($strOPT.tolower()) {
  #PERFORM 'LOCAL' FILTER CONFIGURATIONS
  "local" {
    $strTMP = $null
    #DISABLED TO PREVENT OVER-WRITE OF TECHNICIAN SELECTIONS AT A LATER TIME
    #RESET CURRENT BACKUP INCLUDES , REF #2
    #objOUT.write vbnewline & now & vbtab & vbtab & " - RESETTING CURRENT MSP BACKUP INCLUDES"
    #objLOG.write vbnewline & now & vbtab & vbtab & " - RESETTING CURRENT MSP BACKUP INCLUDES"
    #call HOOK("$($cliPath) control.selection.modify -datasource FileSystem -include C:\")
    #start-sleep -milliseconds 5000
    #REMOVE PREVIOUS 'FILTERS.TXT' FILE
    if (test-path -path "C:\IT\Scripts\filters.txt" -pathtype leaf) {
      remove-item "C:\IT\Scripts\filters.txt" -force
    }
    $script:diag += "`t - Loading : NAble Backup Filters`r`n"
    write-host "`t - Loading : NAble Backup Filters" -foregroundcolor yellow
    $srcTXT = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/MSP%20Backups/filters.txt"
    try {
      $web = new-object system.net.webclient
      $web.DownloadFile($srcTXT, "C:\IT\Scripts\filters.txt")
      $psTXT = get-content "C:\IT\Scripts\filters.txt"
      $script:blnPSTXT = $true
    } catch {
      $script:diag += "`t - Web.DownloadFile() - Could not download $($srcTXT)`r`n"
      write-host "`t - Web.DownloadFile() - Could not download $($srcTXT)" -foregroundcolor red
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
      try {
        start-bitstransfer -erroraction stop -source $srcTXT -destination "C:\IT\Scripts\filters.txt"
        $psTXT = get-content "C:\IT\Scripts\filters.txt"
        $script:blnPSTXT = $true
      } catch {
        $script:blnPSTXT = $false
        $script:diag += "`t - BITS.Transfer() - Could not download $($srcTXT)`r`n"
        write-host "`t - BITS.Transfer() - Could not download $($srcTXT)" -foregroundcolor red
        write-host $_.Exception
        write-host $_.scriptstacktrace
        write-host $_
      }
    }
    
    if ($script:blnPSTXT) {
      foreach ($line in $psTXT) {
        if (($null -ne $line) -and ($line -ne "")) {
          $strPATH = $line
          #EXPAND ENVIRONMENT STRINGS
          if ($line -match "%") {
            if ($line -notmatch "\\") {$line = "$($line)\"}
            $arrPATH = $line.split("\")
            $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
            for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
              $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
            }
          }
          if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
          if ($line -match "\*") {                                #APPLY BACKUP FILTERS
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.filter.modify -add `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
          } elseif ($line -notmatch "\*") {                          #APPLY BACKUP EXCLUSIONS
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
          }
        }
        start-sleep -milliseconds 200
      }
      #CUSTOM 'FILTER' PASSED
      if (($null -ne $strFILTER) -and ($strFILTER -ne "")) {
        if ($strFILTER -notmatch "|") {$strFILTER = "$($strFILTER)|"}
        $arrFILTER = $strFILTER.split("|")
        for ($intTMP = 0; $intTMP -le $arrFILTER.length; $intTMP++) {
          if (($null -ne $arrFILTER[$intTMP]) -and ($arrFILTER[$intTMP] -ne "")) {
            $strPATH = $arrFILTER[$intTMP]
            #EXPAND ENVIRONMENT STRINGS
            if ($arrFILTER[$intTMP] -match "%") {
              if ($arrFILTER[$intTMP] -notmatch "\\") {$arrFILTER[$intTMP] = "$($arrFILTER[$intTMP])\"}
              $arrPATH = $arrFILTER[$intTMP].split("\")
              $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
              for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
                $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
              }
            }
            if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
            if ($arrFILTER[$intTMP] -match "\*") {                 #APPLY BACKUP FILTERS
              $script:diag += "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`"`r`n"
              write-host "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`""
              $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.filter.modify -add `"$($strPATH)`""
              $script:diag += "`t`t`t - $($output)`r`n"
              write-host "`t`t`t - $($output)"
            } elseif ($arrFILTER[$intTMP] -notmatch "\*") {        #APPLY BACKUP EXCLUSIONS
              $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`"`r`n"
              write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
              $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
              $script:diag += "`t`t`t - $($output)`r`n"
              write-host "`t`t`t - $($output)"
            }
            start-sleep -milliseconds 200
          }
        }
      }
    }
    $strTMP = $null
    #DOWNLOAD 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION FILE , 'ERRRET'=2 , REF #2
    #objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION"
    #objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION"
    #REMOVE PREVIOUS 'INCLUDES.TXT' FILE
    if (test-path -path "C:\IT\Scripts\includes.txt" -pathtype leaf) {
      remove-item "C:\IT\Scripts\includes.txt" -force
    }
    $script:diag += "`r`n`r`n`t - Loading : NAble Backup includes`r`n"
    write-host "`r`n`t - Loading : NAble Backup includes" -foregroundcolor yellow
    $srcTXT = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/MSP%20Backups/includes.txt"
    try {
      $web = new-object system.net.webclient
      $web.DownloadFile($srcTXT, "C:\IT\Scripts\includes.txt")
      $psTXT = get-content "C:\IT\Scripts\includes.txt"
      $script:blnPSTXT = $true
    } catch {
      $script:diag += "`t - Web.DownloadFile() - Could not download $($srcTXT)`r`n"
      write-host "`t - Web.DownloadFile() - Could not download $($srcTXT)" -foregroundcolor red
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
      try {
        start-bitstransfer -erroraction stop -source $srcTXT -destination "C:\IT\Scripts\includes.txt"
        $psTXT = get-content "C:\IT\Scripts\includes.txt"
        $script:blnPSTXT = $true
      } catch {
        $script:blnPSTXT = $false
        $script:diag += "`t - BITS.Transfer() - Could not download $($srcTXT)`r`n"
        write-host "`t - BITS.Transfer() - Could not download $($srcTXT)" -foregroundcolor red
        write-host $_.Exception
        write-host $_.scriptstacktrace
        write-host $_
      }
    }
    
    if ($script:blnPSTXT) {
      foreach ($line in $psTXT) {
        if (($null -ne $line) -and ($line -ne "")) {
          $strPATH = $line
          #EXPAND ENVIRONMENT STRINGS
          if ($line -match "%") {
            if ($line -notmatch "\\") {$line = "$($line)\"}
            $arrPATH = $line.split("\")
            $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
            for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
              $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
            }
          }
          #APPLY INCLUDES
          if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
          $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`"`r`n"
          write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
          $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
          $script:diag += "`t`t`t - $($output)`r`n"
          write-host "`t`t`t - $($output)"
        }
        start-sleep -milliseconds 200
      }
      #CUSTOM 'INCLUDE' PASSED
      if (($null -ne $strINCL) -and ($strINCL -ne "")) {
        if ($strINCL -notmatch "|") {$strINCL = "$($strINCL)|"}
        $arrINCL = $strINCL.split("|")
        for ($intTMP = 0; $intTMP -le $arrINCL.length; $intTMP++) {
          if (($null -ne $arrINCL[$intTMP]) -and ($arrINCL[$intTMP] -ne "")) {
            $strPATH = $arrINCL[$intTMP]
            #EXPAND ENVIRONMENT STRINGS
            if ($arrINCL[$intTMP] -match "%") {
              if ($arrINCL[$intTMP] -notmatch "\\") {$arrINCL[$intTMP] = "$($arrINCL[$intTMP])\"}
              $arrPATH = $arrINCL[$intTMP].split("\")
              $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
              for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
                $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
              }
            }
            #APPLY INCLUDES
            if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
            start-sleep -milliseconds 200
          }
        }
      }
    }
  }
  #PERFORM 'CLOUD' FILTER CONFIGURATIONS
  "cloud" {
    $strTMP = $null
    #RESET CURRENT BACKUP INCLUDES , REF #2
    $script:diag += "`t - RESETTING CURRENT MSP BACKUP INCLUDES`r`n"
    write-host "`t - RESETTING CURRENT MSP BACKUP INCLUDES"
    $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"C:\`""
    $script:diag += "`t`t`t - $($output)`r`n"
    write-host "`t`t`t - $($output)"
    start-sleep -milliseconds 60000
    #REMOVE PREVIOUS 'FILTERS.TXT' FILE
    if (test-path -path "C:\IT\Scripts\cloud_filters.txt" -pathtype leaf) {
      remove-item "C:\IT\Scripts\cloud_filters.txt" -force
    }
    $script:diag += "`r`n`r`n`t - Loading : NAble Backup Filters`r`n"
    write-host "`r`n`t - Loading : NAble Backup Filters" -foregroundcolor yellow
    $srcTXT = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/MSP%20Backups/cloud_filters.txt"
    try {
      $web = new-object system.net.webclient
      $web.DownloadFile($srcTXT, "C:\IT\Scripts\cloud_filters.txt")
      $psTXT = get-content "C:\IT\Scripts\cloud_filters.txt"
      $script:blnPSTXT = $true
    } catch {
      $script:diag += "`t - Web.DownloadFile() - Could not download $($srcTXT)`r`n"
      write-host "`t - Web.DownloadFile() - Could not download $($srcTXT)" -foregroundcolor red
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
      try {
        start-bitstransfer -erroraction stop -source $srcTXT -destination "C:\IT\Scripts\cloud_filters.txt"
        $psTXT = get-content "C:\IT\Scripts\cloud_filters.txt"
        $script:blnPSTXT = $true
      } catch {
        $script:blnPSTXT = $false
        $script:diag += "`t - BITS.Transfer() - Could not download $($srcTXT)`r`n"
        write-host "`t - BITS.Transfer() - Could not download $($srcTXT)" -foregroundcolor red
        write-host $_.Exception
        write-host $_.scriptstacktrace
        write-host $_
      }
    }
    
    if ($script:blnPSTXT) {
      foreach ($line in $psTXT) {
        if (($null -ne $line) -and ($line -ne "")) {
          $strPATH = $line
          #EXPAND ENVIRONMENT STRINGS
          if ($line -match "%") {
            if ($line -notmatch "\\") {$line = "$($line)\"}
            $arrPATH = $line.split("\")
            $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
            for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
              $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
            }
          }
          if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
          if ($line -match "\*") {                                #APPLY BACKUP FILTERS
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.filter.modify -add `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
          } elseif ($line -match "\*") {                          #APPLY BACKUP EXCLUSIONS
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
          }
        }
        start-sleep -milliseconds 200
      }
      #CUSTOM 'FILTER' PASSED
      if (($null -ne $strFILTER) -and ($strFILTER -ne "")) {
        if ($strFILTER -notmatch "|") {$strFILTER = "$($strFILTER)|"}
        $arrFILTER = $strFILTER.split("|")
        for ($intTMP = 0; $intTMP -le $arrFILTER.length; $intTMP++) {
          if (($null -ne $arrFILTER[$intTMP]) -and ($arrFILTER[$intTMP] -ne "")) {
            $strPATH = $arrFILTER[$intTMP]
            #EXPAND ENVIRONMENT STRINGS
            if ($arrFILTER[$intTMP] -match "%") {
              if ($arrFILTER[$intTMP] -notmatch "\\") {$arrFILTER[$intTMP] = "$($arrFILTER[$intTMP])\"}
              $arrPATH = $arrFILTER[$intTMP].split("\")
              $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
              for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
                $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
              }
            }
            if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
            if ($arrFILTER[$intTMP] -match "\*") {                 #APPLY BACKUP FILTERS
              $script:diag += "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`"`r`n"
              write-host "`t`t - EXECUTING : $($cliPath) control.filter.modify -add `"$($strPATH)`""
              $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.filter.modify -add `"$($strPATH)`""
              $script:diag += "`t`t`t - $($output)`r`n"
              write-host "`t`t`t - $($output)"
            } elseif ($arrFILTER[$intTMP] -notmatch "\*") {        #APPLY BACKUP EXCLUSIONS
              $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`"`r`n"
              write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
              $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($strPATH)`""
              $script:diag += "$($output)"
              write-host "`t`t`t - $($output)"
            }
            start-sleep -milliseconds 200
          }
        }
      }
    }
    $strTMP = $null
    #DOWNLOAD 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION FILE , 'ERRRET'=2 , REF #2
    #objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION"
    #objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING 'INCLUDES.TXT' BACKUP INCLUDES DEFINITION"
    #REMOVE PREVIOUS 'INCLUDES.TXT' FILE
    if (test-path -path "C:\IT\Scripts\cloud_includes.txt" -pathtype leaf) {
      remove-item "C:\IT\Scripts\cloud_includes.txt" -force
    }
    $script:diag += "`r`n`r`n`t - Loading : NAble Backup Includes`r`n"
    write-host "`r`n`t - Loading : NAble Backup Includes" -foregroundcolor yellow
    $srcTXT = "https://raw.githubusercontent.com/CW-Khristos/scripts/master/MSP%20Backups/cloud_includes.txt"
    try {
      $web = new-object system.net.webclient
      $web.DownloadFile($srcTXT, "C:\IT\Scripts\cloud_includes.txt")
      $psTXT = get-content "C:\IT\Scripts\cloud_includes.txt"
      $script:blnPSTXT = $true
    } catch {
      $script:diag += "`t - Web.DownloadFile() - Could not download $($srcTXT)`r`n"
      write-host "`t - Web.DownloadFile() - Could not download $($srcTXT)" -foregroundcolor red
      write-host $_.Exception
      write-host $_.scriptstacktrace
      write-host $_
      try {
        start-bitstransfer -erroraction stop -source $srcTXT -destination "C:\IT\Scripts\cloud_includes.txt"
        $psTXT = get-content "C:\IT\Scripts\cloud_includes.txt"
        $script:blnPSTXT = $true
      } catch {
        $script:blnPSTXT = $false
        $script:diag += "`t - BITS.Transfer() - Could not download $($srcTXT)`r`n"
        write-host "`t - BITS.Transfer() - Could not download $($srcTXT)" -foregroundcolor red
        write-host $_.Exception
        write-host $_.scriptstacktrace
        write-host $_
      }
    }
    
    if ($script:blnPSTXT) {
      foreach ($line in $psTXT) {
        if (($null -ne $line) -and ($line -ne "")) {
          $strPATH = $line
          #EXPAND ENVIRONMENT STRINGS
          if ($line -match "%") {
            if ($line -notmatch "\\") {$line = "$($line)\"}
            $arrPATH = $line.split("\")
            $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
            for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
              $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
            }
          }
          #APPLY INCLUDES
          if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
          $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`"`r`n"
          write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
          $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
          $script:diag += "`t`t`t - $($output)`r`n"
          write-host "`t`t`t - $($output)"
        }
        start-sleep -milliseconds 200
      }
      #CUSTOM 'INCLUDE' PASSED
      if (($null -ne $strINCL) -and ($strINCL -ne "")) {
        if ($strINCL -notmatch "|") {$strINCL = "$($strINCL)|"}
        $arrINCL = $strINCL.split("|")
        for ($intTMP = 0; $intTMP -le $arrINCL.length; $intTMP++) {
          if (($null -ne $arrINCL[$intTMP]) -and ($arrINCL[$intTMP] -ne "")) {
            $strPATH = $arrINCL[$intTMP]
            #EXPAND ENVIRONMENT STRINGS
            if ($arrINCL[$intTMP] -match "%") {
              if ($arrINCL[$intTMP] -notmatch "\\") {$arrINCL[$intTMP] = "$($arrINCL[$intTMP])\"}
              $arrPATH = $arrINCL[$intTMP].split("\")
              $strPATH = [System.Environment]::ExpandEnvironmentVariables($($arrPATH[0]))
              for ($intPATH = 1; $intPATH -le ($arrPATH.length - 1); $intPATH++) {
                $strPATH = "$($strPATH)\$($arrPATH[$intPATH])"
              }
            }
            #APPLY INCLUDES
            if ($strPATH -match "|") {$strPATH = $strPATH.replace("|", "")}
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($strPATH)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
            start-sleep -milliseconds 200
          }
        }
      }
    }
  }
}
#PERFORM FINAL EXCLUDES
$script:diag += "`r`n`r`n`t - PERFORMING FINAL EXCLUDES`r`n"
write-host "`r`n`t - PERFORMING FINAL EXCLUDES"
#DEFAULT EXCLUDES
for ($intEXCL = 65; $intEXCL -le 90; $intEXCL++) {
  #PROCEED WITH EXCLUDING DEFAULTS
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Temp`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Temp`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Temp`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Recovery`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Recovery`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Recovery`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\RECYCLED`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\RECYCLED`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\RECYCLED`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\AV_ASW`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\AV_ASW`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\AV_ASW`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\GetCurrent`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\GetCurrent`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\GetCurrent`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Recycle.Bin`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Recycle.Bin`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Recycle.Bin`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~BT`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~BT`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~BT`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~WS`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~WS`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\$Windows.~WS`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Windows10Upgrade`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Windows10Upgrade`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\Windows10Upgrade`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\hiberfil.sys`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\hiberfil.sys`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\hiberfil.sys`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\pagefile.sys`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\pagefile.sys`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\pagefile.sys`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\swapfile.sys`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\swapfile.sys`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\swapfile.sys`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 20
  $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\System Volume Information`"`r`n"
  write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\System Volume Information`""
  $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$([char]$($intEXCL)):\System Volume Information`""
  $script:diag += "`t`t`t - $($output)`r`n"
  write-host "`t`t`t - $($output)"
  start-sleep -milliseconds 200
}
#ENUMERATE 'C:\USERS' SUB-FOLDERS
$script:diag += "`r`n`r`n`t - CHECKING USER FOLDERS`r`n"
write-host "`r`n`t - CHECKING USER FOLDERS"
$objFOL = get-childitem -path "C:\Users\" -directory -recurse -erroraction stop
foreach ($subFOL in $objFOL) {
  $script:diag += "$($subFOL.fullname)`r`n"
  write-host $subFOL.fullname
  $arrFOL.add($($subFOL.fullname))
}
#CHECK EACH 'C:\USERS\<USERNAME>' FOLDER
foreach ($subFOL in $arrFOL) {
  $blnFND = $false
  if (($null -ne $subFOL) -and ($subFOL -ne "")) {
    #ENUMERATE THROUGH AND MAKE SURE THIS ISN'T ONE OF THE 'UNNEEDED / TO EXCLUDE' USER ACCOUNTS
    for ($intCOL = 0; $intCOL -le $arrEXCL.length; $intCOL++) {
      $blnFND = $false
      if (($null -ne $arrEXCL[$intCOL]) -and ($arrEXCL[$intCOL] -ne "")) {
        # 'UNNEEDED / TO EXCLUDE' USER ACCOUNT 'ARREXCL' FOUND IN FOLDER PATH
        if ($arrEXCL[$intCOL].tolower() -match $subFOL.tolower()) {
          $script:diag += "`t`t - UNNEEDED / TO EXCLUDE USER : $($arrEXCL[$intCOL])`r`n"
          write-host "`t`t - UNNEEDED / TO EXCLUDE USER : $($arrEXCL[$intCOL])"
          #MARK 'UNNEEDED / TO EXCLUDE'
          $blnFND = $true
          #DISABLED TO PREVENT OVER-WRITE OF TECHNICIAN SELECTIONS AT A LATER TIME
          #PROCEED WITH INCLUDING ENTIRE USER DIRECTORY
          #objOUT.write vbnewline & now & vbtab & vbtab & _
          #  "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34)
          #objLOG.write vbnewline & now & vbtab & vbtab & _
          #  "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34)
          #call HOOK("$($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34))
          #start-sleep -milliseconds 200
          #EXCLUDE USER FOLDER SUB-FOLDERS
          #ENUMERATE 'C:\USERS\<USERNAME>' SUB-FOLDERS
          $objUFOL = get-childitem -path "$($subFOL)" -directory -recurse -erroraction stop
          foreach ($subUFOL in $objUFOL) {
            #PROCEED WITH EXCLUDING USER DIRECTORY SUB-FOLDERS
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subUFOL.fullname)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude `"$($subUFOL.fullname)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -exclude `"$($subUFOL.fullname)`""
            $script:diag +="$($output)`r`n"
            write-host "`t`t`t - $($output)"
            #INCLUDE 'SUB-FOLDER\DESKTOP.INI' FOR EACH SUB-FOLDER TO RETAIN ORIGINAL FOLDER STRUCTURE
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($subUFOL.fullname)\desktop.ini`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($subUFOL.fullname)\desktop.ini`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($subUFOL.fullname)\desktop.ini`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
            start-sleep -milliseconds 200
          }
          break
        }
      }
      #AN 'UNNEEDED / TO EXCLUDE' USER ACCOUNT WAS PASSED TO 'STRUSR'
      #if (wscript.arguments.count > 0) then
      #  '' PASSED 'UNNEEDED / TO EXCLUDE' USER ACCOUNT 'ARREXCL'
      #  if (instr(1, lcase(strFOL), lcase(objARG.item(0)))) then
      #    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "UNNEEDED / TO EXCLUDE : " & objARG.item(0)
      #    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "UNNEEDED / TO EXCLUDE : " & objARG.item(0)
      #    ''MARK 'UNNEEDED / TO EXCLUDE'
      #    blnFND = true
      #    ''PROCEED WITH EXCLUDING ENTIRE USER DIRECTORY
      #    objOUT.write vbnewline & now & vbtab & vbtab & _
      #      "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude " & chr(34) & strFOL & chr(34)
      #    objLOG.write vbnewline & now & vbtab & vbtab & _
      #      "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -exclude " & chr(34) & strFOL & chr(34)
      #    'call HOOK("$($cliPath) control.selection.modify -datasource FileSystem -exclude " & chr(34) & strFOL & chr(34))
      #    exit for
      #  end if          
      #end if
    }
    #NO MATCH TO 'UNNEEDED / TO EXCLUDE' USER ACCOUNTS
    if (-not ($blnFND)) {
      #ENUMERATE THROUGH AND MAKE SURE THIS ISN'T ONE OF THE 'PROTECTED' USER ACCOUNTS
      $intPCOL = 0
      for ($intPCOL = 0; $intPCOL -le $arrPUSR.length; $intPCOL++) {
        $blnFND = $false
        if (($null -ne $arrPUSR[$intPCOL]) -and ($arrPUSR[$intPCOL] -ne "")) {
          #objOUT.write vbnewline & arrPUSR(intPCOL)
          # 'PRTOTECTED' USER ACCOUNTS DIRECTORIES 'ARRPUSR' FOUND IN FOLDER PATH
          if ($arrPUSR[$intPCOL] -match $subFOL) {
            $script:diag += "`t`t - PROTECTED : $($arrPUSR[$intPCOL])`r`n"
            write-host "`t`t - PROTECTED : $($arrPUSR[$intPCOL])"
            #PROCEED WITH INCLUDING ENTIRE USER DIRECTORY
            $script:diag += "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($subUFOL)`"`r`n"
            write-host "`t`t - EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include `"$($subUFOL)`""
            $output = Get-ProcessOutput -filename "$($cliPath)" -args "control.selection.modify -datasource FileSystem -include `"$($subUFOL)`""
            $script:diag += "`t`t`t - $($output)`r`n"
            write-host "`t`t`t - $($output)"
            start-sleep -milliseconds 200
            #MARK 'PROTECTED'
            $blnFND = $true
            break
          }
        }
      }
      #NO MATCH TO 'PROTECTED' USER ACCOUNTS
      if (-not ($blnFND)) {
        #CHECK FOR USER FOLDER
        if (test-path -path "$($subFOL)") {
          $script:diag += "`t`t - ENUMERATING : $($subFOL)`r`n"
          write-host "`t`t - ENUMERATING : $($subFOL)"
          #DISABLED TO PREVENT OVER-WRITE OF TECHNICIAN SELECTIONS AT A LATER TIME
          #PROCEED WITH INCLUDING ENTIRE USER DIRECTORY
          #objOUT.write vbnewline & now & vbtab & vbtab & _
          #  "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34)
          #objLOG.write vbnewline & now & vbtab & vbtab & _
          #  "EXECUTING : $($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34)
          #call HOOK("$($cliPath) control.selection.modify -datasource FileSystem -include " & chr(34) & strFOL & chr(34))
          #start-sleep -milliseconds 200
          #ENUMERATE 'C:\USERS\<USERNAME>\APPDATA' SUB-FOLDERS
          for ($intUFOL = 0; $intUFOL -le $arrAPP.length; $intUFOL++) {
            if (($null -ne $arrAPP[$intUFOL]) -and ($arrAPP[$intUFOL] -ne "")) {
              chkSFOL "$($subFOL)$($arrAPP[$intUFOL])"
            }
          }
        }
      }
    }
  }
}
$script:diag += "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_FILTER COMPLETE`r`n"
write-host "$((Get-Date).ToString('dd-MM-yyyy hh:mm:ss')) - MSP_FILTER COMPLETE"
#Stop script execution time calculation
StopClock
#WRITE LOGFILE
$script:diag | out-file $logPath
#DATTO OUTPUT
if ($script:blnWARN) {
  write-DRRMAlert "MSP_FILTER : Execution Failure : See Diagnostics"
  write-DRMMDiag "$($script:diag)"
  exit 1
} elseif (-not $script:blnWARN) {
  write-DRRMAlert "MSP_FILTER : Completed Execution"
  write-DRMMDiag "$($script:diag)"
  exit 0
}
#END SCRIPT
#------------