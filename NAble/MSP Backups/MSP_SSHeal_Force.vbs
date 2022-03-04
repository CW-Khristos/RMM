''MSP_SSHEAL_FORCE.VBS
''SCRIPT IS DESIGNED TO ATTEMPT FORCE SELF-HEAL OF MSP BACKUP SYSTEM STATE USING 'NET' CMD AND CLIENTTOOL.EXE UTILITY
''SCRIPT WILL CHECK STATUS OF BACKUPS PRIOR TO EXECUTION; IF BACKUPS ARE IN PROGRESS, SCRIPT WILL NOT PROCEED
''CHECKS STATUS OF BACKUPS, FORCES RESTART OF SERVICES, CHECKS VSS WRITERS AND RESTARTS SERVICES IF NEEDED, RE-RUNS SYSTEM STATE BACKUPS
''MUST BE USED IN CONJUNCTION WITH MSP BACKUP SYSTEM STATE BACKUP MONITORED SERVICE
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim errRET, strVER
dim blnRUN, blnSUP
dim strREPO, strBRCH, strDIR
dim strIDL, strTMP, arrTMP, strIN
''SCRIPT OBJECTS
dim objIN, objOUT, objARG, objWSH
dim objFSO, objLOG, objHOOK, objHTTP
''VSS WRITER FLAGS
dim blnIIS, blnNPS, blnTSG
dim blnAHS, blnBIT, blnCSVC, blnRDP
dim blnSQL, blnTSK, blnVSS, blnWMI, blnWSCH
''SET 'ERRRET' CODE
errRET = 0
''VERSION FOR SCRIPT UPDATE, MSP_SSHEAL_FORCE.VBS, REF #2 , FIXES #4
strVER = 16
strREPO = "scripts"
strBRCH = "master"
strDIR = "MSP Backups"
''DEFAULT 'BLNRUN' FLAG - RESTART BACKUPS IF WRITERS ARE STABLE
blnRUN = false
''DEFAULT 'BLNSUP' FLAG - SUPPRESS ERRORS IN CALL HOOK(), REF #19
blnSUP = false
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\MSP_SSHEAL_FORCE")) then		  ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\MSP_SSHEAL_FORCE", true
  set objLOG = objFSO.createtextfile("C:\temp\MSP_SSHEAL_FORCE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_SSHEAL_FORCE", 8)
else                                                        ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\MSP_SSHEAL_FORCE")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\MSP_SSHEAL_FORCE", 8)
end if
''CHECK FOR MSP BACKUP MANAGER CLIENTTOOL , REF #76
if (objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(0)                                            ''CLIENTTOOL.EXE PRESENT, CONTINUE SCRIPT, 'ERRRET'=0
elseif (not objFSO.fileexists("C:\Program Files\Backup Manager\clienttool.exe")) then
  call LOGERR(1)                                            ''CLIENTTOOL.EXE NOT PRESENT, END SCRIPT, 'ERRRET'=1
end if
''CHECK 'PERSISTENT' FOLDERS , REF #2 , REF #73
if (not (objFSO.folderexists("c:\temp"))) then
  objFSO.createfolder("c:\temp")
end if
if (not (objFSO.folderexists("C:\IT\"))) then
  objFSO.createfolder("C:\IT\")
end if
if (not (objFSO.folderexists("C:\IT\Scripts\"))) then
  objFSO.createfolder("C:\IT\Scripts\")
end if
''CHECK EXECUTION METHOD OF SCRIPT
strIN = lcase(mid(wscript.fullname, instrrev(wscript.fullname, "\") + 1))
if (strIN <> "cscript.exe") Then
	''needs to save and pass arguments
  objOUT.write vbnewline & "SCRIPT LAUNCHED VIA EXPLORER, EXECUTING SCRIPT VIA CSCRIPT..."
  objWSH.run "cscript.exe //nologo " & chr(34) & Wscript.ScriptFullName & chr(34)
  wscript.quit
end if

''SET ALL VSS 'FLAGS' TO 'TRUE' TO FORCE RESTART , REF #1
blnAHS = true
blnBIT = true
blnCSVC = true
blnIIS = true
blnNPS = true
blnRDP = true
blnSQL = true
blnSUP = true
blnTSG = true
blnTSK = true
blnVSS = true
blnWMI = true
blnWSCH = true
''------------
''BEGIN SCRIPT
objOUT.write vbnewline & now & " - STARTING MSP_SSHEAL_FORCE" & vbnewline
objLOG.write vbnewline & now & " - STARTING MSP_SSHEAL_FORCE" & vbnewline
if (errRET = 0) then
  ''AUTOMATIC UPDATE, MSP_SSHEAL_FORCE.VBS, REF #2 , REF #69 , REF #68 , FIXES #4
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_SSHEAL_FORCE : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : MSP_SSHEAL_FORCE : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #69 , REF #68
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\temp\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #69 , REF #68
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    ''CHECK MSP BACKUP STATUS VIA MSP BACKUP CLIENTTOOL UTILITY
    objOUT.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    objLOG.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
    set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
    strIDL = objHOOK.stdout.readall
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
    set objHOOK = nothing
    if ((strIDL = vbnullstring) or (instr(1, strIDL, "Idle")) or (instr(1, strIDL, "RegSync")) or _
      (instr(1, strIDL, "Suspended"))) then                 ''BACKUPS NOT IN PROGRESS
        objOUT.write vbnewline & now & vbtab & vbtab & " - BACKUPS NOT IN PROGRESS, STOPPING BACKUP SERVICE, CHECKING VSS WRITERS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - BACKUPS NOT IN PROGRESS, STOPPING BACKUP SERVICE, CHECKING VSS WRITERS"
        ''STOP BACKUP SERVICE
        call HOOK("net stop " & chr(34) & "Backup Service Controller" & chr(34)
        ''VSS WRITER SERVICES - RESTART TO RESET ASSOCIATED VSS WRITER
        call VSSSVC()
        ''CHECK VSS WRITERS AFTER RESTART
        objOUT.write vbnewline & now & vbtab & vbtab & " - SERVICES RESTART COMPLETE, CHECKING VSS WRITERS"
        objLOG.write vbnewline & now & vbtab & vbtab & " - SERVICES RESTART COMPLETE, CHECKING VSS WRITERS"
        ''EXPORT CURRENT VSS WRITER STATUSES , 'ERRRET'=4
        call CHKVSS()
        ''VSS WRITER SERVICES - RESTART TO RESET ASSOCIATED VSS WRITER
        call VSSSVC()
        ''CHECK FOR WMI DEPENDENT SERVICES, REF #19
        call CHKDEP()
        ''RESTART BACKUP SERVICE
        call HOOK("net start " & chr(34) & "Backup Service Controller" & chr(34)
        wscript.sleep 5000
        ''CHECK MSP BACKUP STATUS VIA MSP BACKUP CLIENTTOOL UTILITY AFTER RESTART
        for intLOOP = 0 to 10
          objOUT.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
          objLOG.write vbnewline & now & vbtab & " - CHECKING MSP BACKUP STATUS"
          set objHOOK = objWSH.exec(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.status.get")
          strIDL = objHOOK.stdout.readall
          objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
          objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIDL
          set objHOOK = nothing
          ''BACKUPS NOT IN PROGRESS
          if ((instr(1, strIDL, "Idle")) or (instr(1, strIDL, "RegSync"))) then
              ''FORCE RUN OF SYSTEM STATE
              blnRUN = true
              if (blnRUN) then														  ''RE-RUN SYSTEM STATE BACKUPS
                ''ADDITIONAL DELAY TO GIVE SERVICE A BIT EXTRA Time
                wscript.sleep (60000)
                objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "VSS WRITERS RESET, RUNNING SYSTEM STATE BACKUP"
                objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "VSS WRITERS RESET, RUNNING SYSTEM STATE BACKUP"
                call HOOK(chr(34) & "c:\Program Files\Backup Manager\ClientTool.exe" & chr(34) & " control.backup.start -datasource SystemState")
                blnRUN = false
              elseif (not blnRUN) then										  ''DO NOT RE-RUN SYSTEM STATE BACKUPS
                objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "VSS WRITERS STABLE" 
                objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "VSS WRITERS STABLE"
              end if
              exit for
          ''BACKUPS IN PROGRESS, SERVICE NOT READY
          elseif ((strIDL = vbnullstring) or (instr(1, strIDL, "Idle") = 0) or _
            (instr(1, strIDL, "RegSync") = 0) or (instr(1, strIDL, "Suspended"))) then
              objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "BACKUPS IN PROGRESS, SERVICE NOT READY" 
              objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "BACKUPS IN PROGRESS, SERVICE NOT READY"
              blnRUN = true
          end if
          wscript.sleep 12000
        next
        if (blnRUN) then                                    ''SERVICE DID NOT INITIALIZE , 'ERRRET'=6
          call LOGERR(6)
        end if
    elseif ((instr(1, strIDL, "Idle") = 0) or (instr(1, strIDL, "RegSync") = 0) or _
      (instr(1, strIDL, "Suspended") = 0)) then					    ''BACKUPS IN PROGRESS, SERVICE NOTE READY , 'ERRRET'=3
        call LOGERR(3)
    end if
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''FUNCTIONS
function CHKSTAT(strSTAT)                                   ''CHECK VSS WRITER STATE
  if (instr(1, strSTAT, "State:")) then
    if (instr(1, strSTAT, "Stable") = 0) then               ''VSS WRITER IN ERROR STATE
      CHKSTAT = true
    elseif (instr(1, strSTAT, "Stable")) then               ''VSS WRITER STABLE
      CHKSTAT = false
    end if
  end if
end function

''SUB-ROUTINES
sub CHKDEP()                                                ''RESTART WMI DEPENDENT SERVICES, REF #19
  ''DEPENDENT SERVICES WHICH MAY NEED RESTART AFTER RESTART OF WMI
  objOUT.write vbnewline & now & vbtab & vbtab & " - RESTARTING WMI DEPENDENT SERVICES"
  objLOG.write vbnewline & now & vbtab & vbtab & " - RESTARTING WMI DEPENDENT SERVICES"
  call HOOK("net start " & chr(34) & "Security Center" & chr(34))
  call HOOK("net start " & chr(34) & "System Update" & chr(34))
  call HOOK("net start " & chr(34) & "IP Helper" & chr(34))
  call HOOK("net start " & chr(34) & "VMware USB Arbitration Service" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) Rapid Storage Technology" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) PROSet/Wireless Event Log" & chr(34))
  call HOOK("net start " & chr(34) & "Intel(R) HD Graphics Control Panel Service" & chr(34))
  call HOOK("net start " & chr(34) & "Dell Foundation Services" & chr(34))
  call HOOK("net start " & chr(34) & "User Access Logging Service" & chr(34))
  call HOOK("net start " & chr(34) & "Background Intelligent Transfer Service" & chr(34))
  call HOOK("net start " & chr(34) & "System Event Notification Service" & chr(34))
end sub

sub CHKVSS()																				        ''CHECK VSS WRITER STATUSES , 'ERRRET'=4
  ''CAPTURE 'VSSADMIN LIST WRITERS' OUTPUT
  set objHOOK = objWSH.exec("vssadmin list writers")
  strTMP = objHOOK.stdout.readall
  set objHOOK = nothing
  ''SEPARATE CAPTURED OUTPUT BY NEWLINE
  arrTMP = split(strTMP, vbnewline)
  for intTMP = 0 to ubound(arrTMP)
    if (arrTMP(intTMP) <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & arrTMP(intTMP) 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & arrTMP(intTMP)
      ''VSS ERROR, PAUSE 60SEC, STOP VSS, PAUSE 60SEC, START VSS, PAUSE 30SEC , 'ERRRET'=4
      if (instr(1, arrTMP(intTMP), "Error: A Volume Shadow Copy Service component encountered an unexpected error.")) then
        x = 0
        while x <= 60
          x = x + 1
          wscript.sleep 1000
        wend
        call LOGERR(4)
        ''STOP VSS SERVICE
        call HOOK("net stop VSS")
        x = 0
        while x <= 60
          x = x + 1
          wscript.sleep 1000
        wend
        ''RESTART VSS SERVICE
        call HOOK ("net start VSS")
        x = 0
        while x <= 30
          x = x + 1
          wscript.sleep 1000
        wend
        exit for
      end if
      ''LOCATE VSS WRITERS
      if ((instr(1, arrTMP(intTMP), "name: "))) then
        select case (replace(split(arrTMP(intTMP), "name: ")(1), "'", vbnullstring))
          case "BITS Writer"
            ''CHECK VSS WRITER STATE
            blnBIT = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnBIT : " & blnBIT  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnBIT : " & blnBIT
          case "System Writer"
            ''CHECK VSS WRITER STATE
            blnCSVC = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnCSVC : " & blnCSVC  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnCSVC : " & blnCSVC 
          case "Task Scheduler Writer"
            ''CHECK VSS WRITER STATE
            blnTSK = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnTSK : " & blnTSK  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnTSK : " & blnTSK 
          case "ASR Writer", "COM+ REGDB Writer", "Registry Writer", "Shadow Copy Optimization Writer"
            ''CHECK VSS WRITER STATE
            blnVSS = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnVSS : " & blnVSS  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnVSS : " & blnVSS 
          case "MSSearch Service Writer"
            ''CHECK WINDOWS SEARCH WRITER STATE
            blnWSCH = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnWSCH : " & blnWSCH  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnWSCH : " & blnWSCH
          case "WMI Writer"
            ''CHECK VSS WRITER STATE
            blnWMI = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnWMI : " & blnWMI  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnWMI : " & blnWMI 
          case "NPS VSS Writer" 
            ''CHECK VSS WRITER STATE
            blnNPS = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnNPS : " & blnNPS  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnNPS : " & blnNPS
          ''TERMINAL SERVICES
          case "TermServLicensing"
            ''CHECK VSS WRITER STATE
            blnRDP = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnRDP : " & blnRDP  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnRDP : " & blnRDP 
          case "TS Gateway Writer"
            ''CHECK VSS WRITER STATE
            blnTSG = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnTSG : " & blnTSG  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnTSG : " & blnTSG 
          ''SQL SERVICES
          case "SqlServerWriter" 
            ''CHECK VSS WRITER STATE
            blnSQL = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnSQL : " & blnSQL  
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnSQL : " & blnSQL
          ''IIS SERVICES
          case "IIS Config Writer"
            ''CHECK VSS WRITER STATE
            blnAHS = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnAHS : " & blnAHS 
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnAHS : " & blnAHS
          case "IIS Metabase Writer"
            ''CHECK VSS WRITER STATE
            blnIIS = CHKSTAT(arrTMP(intTMP + 3))
            objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "blnIIS : " & blnIIS 
            objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "blnIIS : " & blnIIS
        end select
      end if
    end if
  next
  ''ERROR RETURNED INTERFACING VSS , 'ERRRET'=4
  if ((err.number <> 0) or (errRET = 4)) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    call LOGERR(4)
  end if  
end sub

sub VSSSVC()                                 				        ''VSS WRITER SERVICES - RESTART TO RESET ASSOCIATED VSS WRITER
  ''VSS WRITERS STABLE, RE-RUN MSP BACKUP SYSTEM STATE BACKUP
  if (not ((blnAHS) and (blnIIS) and (blnBIT) and (blnRDP) and (blnTSG) and _
    (blnSQL) and (blnNPS)  and (blnWSCH) and (blnWMI) and (blnVSS) and (blnTSK) and (blnCSVC))) then
      ''SET 'BLNRUN' FLAG
      if (blnRUN) then
        blnRUN = false
      end if
  ''VSS WRITERS REQUIRE RESET, DO NOT RE-RUN MSP BACKUP SYSTEM STATE BACKUP , ADDED 'SC QUERY' CALLS TO AVOID ATTEMPTING PS CALL TO NON-EXISTENT SERVICES
  elseif ((blnAHS) or (blnIIS) or (blnBIT) or (blnRDP) or (blnTSG) or _
    (blnSQL) or (blnNPS)  or (blnWSCH) or (blnWMI) or (blnVSS) or (blnTSK) or (blnCSVC)) then
      ''SET 'BLNRUN' FLAG
      blnRUN = true
      ''IIS
      ''APPLICATION HOST HELPER - AppHostSvc
      if (blnAHS) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query AppHostSvc", 0, true)
        if (intRET = 0) then
          call HOOK("net stop AppHostSvc /y")
          call HOOK ("net start AppHostSvc")
        end if
      end if
      ''IISADMIN - IIS ADMIN
      if (blnIIS) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query IISADMIN", 0, true)
        if (intRET = 0) then
          call HOOK("net stop IISADMIN /y")
          call HOOK ("net start IISADMIN")
        end if
      end if
      ''BITS SERVICES - BITS
      if (blnBIT) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query BITS", 0, true)
        if (intRET = 0) then
          call HOOK("net stop BITS /y")
          call HOOK ("net start BITS")
        end if
      end if
      ''TERMINAL SERVICES
      ''REMOTE DESKTOP LICENSING - TermServLicensing
      if (blnRDP) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query TermServLicensing", 0, true)
        if (intRET = 0) then
          call HOOK("net stop TermServLicensing /y")
          call HOOK ("net start TermServLicensing")
        end if
      end if
      ''REMOTE DESKTOP GATEWAY - TSGateway
      if (blnTSG) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query TSGateway", 0, true)
        if (intRET = 0) then
          call HOOK("net stop TSGateway /y")
          call HOOK ("net start TSGateway")
        end if
      end if
      ''SQL SERVICES
      ''SQL SERVER VSS WRITER - SQLWriter
      if (blnSQL) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query SQLWriter", 0, true)
        if (intRET = 0) then
          call HOOK("net stop SQLWriter /y")
          call HOOK ("net start SQLWriter")
        end if
      end if
      ''NPS VSS WRITER - EventSystem
      if (blnNPS) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query EventSystem", 0, true)
        if (intRET = 0) then
          call HOOK("net stop EventSystem /y")
          call HOOK ("net start EventSystem")
        end if
      end if
      ''WINDOWS SEARCH SERVICE - WSearch
      if (blnWSCH) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query WSearch", 0, true)
        if (intRET = 0) then
          call HOOK("net stop WSearch /y")
          call HOOK ("net start WSearch")
        end if
      end if
      ''WINDOWS MANAGEMENT INSTRUMENTATION - Winmgmt
      if (blnWMI) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'NET STOP' AND 'NET START'
        intRET = objWSH.run ("sc query Winmgmt", 0, true)
        if (intRET = 0) then
          call HOOK("net stop Winmgmt /y")
          call HOOK ("net start Winmgmt")
        end if
      end if
      ''VOLUME SHADOW COPY - VSS
      if (blnVSS) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'POWERSHELL RESTART-SERVICE'
        intRET = objWSH.run ("sc query VSS", 0, true)
        if (intRET = 0) then
          intRET = objWSH.run ("powershell -OutputFormat Text -Command " & chr(34) & "Restart-Service VSS -Force -PassThru" & chr(34), 0, true)
        end if
      end if
      wscript.sleep 1000
      ''CRYPTOGRAPHIC SERVICES - CryptSvc
      if (blnCSVC) then
        ''CHECK FOR SERVICE PRIOR TO RUNNING 'POWERSHELL RESTART-SERVICE'
        intRET = objWSH.run ("sc query CryptSvc", 0, true)
        if (intRET = 0) then
          intRET = objWSH.run ("powershell -OutputFormat Text -Command " & chr(34) & "Restart-Service CryptSvc -Force -PassThru" & chr(34), 0, true)
        end if
      end if
  end if
end sub

sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''CREATE HTTP OBJECT
  set objHTTP = createobject( "WinHttp.WinHttpRequest.5.1" )
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
  ''CHECK IF FILE ALREADY EXISTS
  if (objFSO.fileexists(strSAV)) then
    ''DELETE FILE FOR OVERWRITE
    objFSO.deletefile(strSAV)
  end if
  if (objHTTP.status = 200) then
    dim objStream
    set objStream = createobject("ADODB.Stream")
    with objStream
      .Type = 1 'adTypeBinary
      .Open
      .Write objHTTP.ResponseBody
      .SaveToFile strSAV
      .Close
    end with
    set objStream = nothing
  end if
  ''CHECK THAT FILE EXISTS
  if (objFSO.fileexists(strSAV)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
  set objHTTP = nothing
  ''ERROR RETURNED
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description
    call LOGERR(11)
    err.clear
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : " & strCMD
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
        objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
      objLOG.write vbnewline & now & vbtab & vbtab & vbtab & strIN 
    end if
  end if
  ''CHECK FOR ERRORS
  errRET = objHOOK.exitcode
  set objHOOK = nothing
  if ((not blnSUP) and (err.number <> 0)) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description
    call LOGERR(12)
  end if
end sub

sub LOGERR(intSTG)                                          ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
    objLOG.write vbnewline & now & vbtab & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  select case intSTG
    case 0                                                  ''MSP_SSHEAL_FORCE - CLIENTTOOL CHECK PASSED, 'ERRRET'=0
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CLIENTTOOL CHECK PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CLIENTTOOL CHECK PASSED"
    case 1                                                  ''MSP_SSHEAL_FORCE - CLIENTTOOL CHECK FAILED, 'ERRRET'=1
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CLIENTTOOL CHECK FAILED, ENDING MSP_SSHEAL_FORCE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CLIENTTOOL CHECK FAILED, ENDING MSP_SSHEAL_FORCE"
    case 2                                                  ''MSP_SSHEAL_FORCE - NOT ENOUGH ARGUMENTS , 'ERRRET'=2
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - NOT ENOUGH ARGUMENTS PASSED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - NOT ENOUGH ARGUMENTS PASSED"
    case 3                                                  ''MSP_SSHEAL_FORCE - BACKUPS IN PROGRESS, SERVICE NOT READY , 'ERRRET'=3
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - BACKUPS IN PROGRESS, SERVICE NOT READY, ENDING MSP_SSHEAL_FORCE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - BACKUPS IN PROGRESS, SERVICE NOT READY, ENDING MSP_SSHEAL_FORCE"
    case 4                                                  ''MSP_SSHEAL_FORCE - CALL CHKVSS() , 'ERRRET'=4
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL CHKVSS() : " & err.number & vbtab & err.description
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL CHKVSS() : " & err.number & vbtab & err.description
    case 6                                                  ''MSP_SSHEAL_FORCE - BACKUP SERVICE NOT READY , 'ERRRET'=6
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - BACKUP SERVICE NOT READY, ENDING MSP_SSHEAL_FORCE"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - BACKUP SERVICE NOT READY, ENDING MSP_SSHEAL_FORCE"
    case 11                                                 ''MSP_SSHEAL_FORCE - CALL FILEDL() , 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL FILEDL() : " & strSAV
    case 12                                                 ''MSP_SSHEAL_FORCE - 'VSS CHECKS' - MAX ITERATIONS REACHED , 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                 			        ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         											        ''MSP_SSHEAL_FORCE COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE SUCCESSFUL : " & now
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    											        ''MSP_SSHEAL_FORCE FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE FAILURE : " & errRET & " : " & now
    objOUT.write vbnewline & vbnewline & now & vbtab & " - MSP_SSHEAL_FORCE FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE, ERROR CODE WILL BE DEFINE RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "MSP_SSHEAL_FORCE", "FAILURE")
  end if
  objOUT.write vbnewline & vbnewline & now & " - MSP_SSHEAL_FORCE COMPLETE" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - MSP_SSHEAL_FORCE COMPLETE" & vbnewline
  objLOG.close
  ''EMPTY OBJECTS
  set objLOG = nothing
  set objFSO = nothing
  set objWSH = nothing
  set objARG = nothing
  set objOUT = nothing
  set objIN = nothing
  ''END SCRIPT, RETURN ERROR NUMBER
  wscript.quit err.number
end sub