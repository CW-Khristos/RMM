''AUTO_PLANv2.VBS
''DESIGNED TO AUTOMATE PROTECTION PLAN SETUP
''RUNS CUSTOMIZED MODULE "STAGES" REPRESENTING SECTIONS OF PLAN SETUP
''RUN ON LOCAL DEVICE WITH ADMINISTRATIVE PRIVILEGES
''COMPUTER RENAME WILL REQUIRE REBOOT AND RE-RUN OF SCRIPT
''CURRENTLY ONLY CREATES / UPDATES LOCAL RMMTECH USER
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
on error resume next
''SCRIPT VARIABLES
dim strVER, errRET, strSEL
dim strREPO, strBRCH, strDIR
''VARIABLES ACCEPTING PARAMETERS - CONFIGURES SNMP TRAP AND COMMUNITY STRING
dim strSNMP, strTRP
''SCRIPT OBJECTS
dim objIN, objOUT, objARG
dim objWSH, objFSO, objLOG
dim objHOOK, objEXEC, objHTTP, objXML
''VERSION FOR SCRIPT UPDATE, AUTO_PLAN.VBS, REF #2 , REF #6 , FIXES #5 , FIXES #7
strVER = 15
strREPO = "scripts"
strBRCH = "dev"
strDIR = vbnullstring
''DEFAULT SUCCESS
errRET = 0
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
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
''CONNECT TO WMI REGISTRY PROVIDER
strCOMP = "."
Set objWMI = createobject("winmgmts:{impersonationLevel=impersonate}!\\" & strCOMP & "\root\cimv2")
''PREPARE LOGFILE
if (objFSO.fileexists("C:\temp\auto_planv2")) then          ''LOGFILE EXISTS
  objFSO.deletefile "C:\temp\auto_planv2", true
  set objLOG = objFSO.createtextfile("C:\temp\auto_planv2")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\auto_planv2", 8)
else                                                  	    ''LOGFILE NEEDS TO BE CREATED
  set objLOG = objFSO.createtextfile("C:\temp\auto_planv2")
  objLOG.close
  set objLOG = objFSO.opentextfile("C:\temp\auto_planv2", 8)
end if
''READ PASSED COMMANDLINE ARGUMENTS - REQUIRES (AT LEAST) 2 ARGUMENTS
if (wscript.arguments.count > 0) then                 	    ''ARGUMENTS WERE PASSED
  ''ARGUMENT OUTPUT DISABLED TO SANITIZE
  'for x = 0 to (wscript.arguments.count - 1)
  '  objOUT.write vbnewline & now & vbtab & "ARGUMENT " & (x + 1) & " (ITEM " & x & ") " & " PASSED : " & ucase(objARG.item(x))
  'next
  if (wscript.arguments.count > 1) then
  else
  end if
else
end if

''------------
''BEGIN SCRIPT
if (errRET = 0) then
  objOUT.write vbnewline & vbnewline & now & " - STARTING AUTO_PLANv2" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - STARTING AUTO_PLANv2" & vbnewline
	''AUTOMATIC UPDATE, AUTO_PLAN.VBS, REF #2 , REF #68 , REF #69 , FIXES #5
  objOUT.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : AUTO_PLANv2 : " & strVER
  objLOG.write vbnewline & now & vbtab & vbtab & " - CHECKING FOR UPDATE : AUTO_PLANv2 : " & strVER
  ''DOWNLOAD CHKAU.VBS SCRIPT, REF #2 , REF #68 , REF #69
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/chkAU.vbs", "C:\IT\Scripts", "chkAU.vbs")
  ''EXECUTE CHKAU.VBS SCRIPT, REF #69
  intRET = objWSH.run ("cmd.exe /C " & chr(34) & "cscript.exe " & chr(34) & "C:\temp\chkAU.vbs" & chr(34) & " " & _
    chr(34) & strREPO & chr(34) & " " & chr(34) & strBRCH & chr(34) & " " & chr(34) & strDIR & chr(34) & " " & _
    chr(34) & wscript.scriptname & chr(34) & " " & chr(34) & strVER & chr(34) & chr(34), 0, true)
  ''CHKAU RETURNED - NO UPDATE FOUND , REF #2 , REF #68 , REF #69
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  intRET = (intRET - vbObjectError)
  objOUT.write vbnewline & "errRET='" & intRET & "'"
  objLOG.write vbnewline & "errRET='" & intRET & "'"
  if ((intRET = 4) or (intRET = 10) or (intRET = 11) or (intRET = 1) or (intRET = 2147221505) or (intRET = 2147221517)) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : AUTO_PLANv2 : " & strVER
    objLOG.write vbnewline & now & vbtab & vbtab & " - NO UPDATE FOUND : AUTO_PLANv2 : " & strVER
    ''------------
    ''BEGIN MAINLOOP - LOOPED ENTRY PERMITS SELECTING OPTIONS IN SEQUENCE
    ''ALLOWS FOR STAGES TO BE SELECTED IN A LOOP
    ''ENTERING 'Q' OR 'QUIT' WILL END THE LOOP
    ''SELECTING STAGE2 WILL FORCE REBOOT AND SCRIPT WILL NEED TO BE RUN AGAIN
    blnEND = false
    while (blnEND = false)
      strSEL = vbnullstring
      objOUT.write vbnewline & now & vbtab & " - SELECT WHICH STAGE TO RUN" & vbnewline
      objLOG.write vbnewline & now & vbtab & " - SELECT WHICH STAGE TO RUN" & vbnewline
      objOUT.write vbnewline & vbtab & vbtab & " - PRE-REQUISITES : "
      objOUT.write vbnewline & vbtab & vbtab & " - (1)STAGE1 - SET POWER PLAN & NETWORK DISCOVERY" & vbnewline & vbtab & vbtab & " - (2)STAGE2 - RENAME COMPUTER (RESTART REQ.)"
      objLOG.write vbnewline & vbtab & vbtab & " - (1)STAGE1 - SET POWER PLAN & NETWORK DISCOVERY" & vbnewline & vbtab & vbtab & " - (2)STAGE2 - RENAME COMPUTER (RESTART REQ.)"
      objOUT.write vbnewline & vbtab & vbtab & " - (3)STAGE3 - SETUP RMMTECH (LOCAL / DOMAIN) / JOIN DOMAIN (RESTART REQ.)" & vbnewline & vbtab & vbtab & " - (4)STAGE4 - INSTALL & CONFIGURE SNMP"
      objLOG.write vbnewline & vbtab & vbtab & " - (3)STAGE3 - SETUP RMMTECH (LOCAL / DOMAIN) / JOIN DOMAIN (RESTART REQ.)" & vbnewline & vbtab & vbtab & " - (4)STAGE4 - INSTALL & CONFIGURE SNMP"
      objOUT.write vbnewline & vbtab & vbtab & " - AGENT / PROBE SETUP : "
      objOUT.write vbnewline & vbtab & vbtab & " - (5)STAGE5 - SETUP WINDOWS AGENT" & vbnewline & vbtab & vbtab & " - (6)STAGE6 - SETUP WINDOWS PROBE"
      objLOG.write vbnewline & vbtab & vbtab & " - (5)STAGE5 - SETUP WINDOWS AGENT" & vbnewline & vbtab & vbtab & " - (6)STAGE6 - SETUP WINDOWS PROBE"
      objOUT.write vbnewline & vbtab & vbtab & " - (7)STAGE7 - AV MONITORING AND SERVICES" & vbnewline & vbtab & vbtab & " - (8)STAGE8 - PATCHING MONITORING AND SERVICES"
      objLOG.write vbnewline & vbtab & vbtab & " - (7)STAGE7 - AV MONITORING AND SERVICES" & vbnewline & vbtab & vbtab & " - (8)STAGE8 - PATCHING MONITORING AND SERVICES"
      objOUT.write vbnewline & vbtab & vbtab & " - (9)STAGE9 - BACKUP MONITORING AND SERVICES"
      objLOG.write vbnewline & vbtab & vbtab & " - (9)STAGE9 - BACKUP MONITORING AND SERVICES"
      objOUT.write vbnewline & vbtab & vbtab & " - (Q)QUIT - END SCRIPT" & vbnewline & vbtab & vbtab
      objLOG.write vbnewline & vbtab & vbtab & " - (Q)QUIT - END SCRIPT" & vbnewline & vbtab & vbtab
      strSEL = objIN.readline
      ''CHECK FOR QUIT
      if ((lcase(strSEL) = "q") or (lcase(strSEL) = "quit")) then
        strSEL = 10
        blnEND = true
      end if
      select case strSEL
        case 0                                                ''STAGE0 - BASE SOFTWARE DEPLOYMENT
          call STAGE0()
        case 1                                                ''STAGE1 - SET POWER PLAN & NETWORK DISCOVERY
          call STAGE1()
        case 2                                                ''STAGE2 - RENAME COMPUTER (RESTART REQ.)
          call STAGE2()
        case 3                                                ''STAGE3 - SETUP RMMTECH (LOCAL / DOMAIN) / JOIN DOMAIN (RESTART REQ.)
          call STAGE3()
        case 4                                                ''STAGE4 - INSTALL & CONFIGURE SNMP
          call STAGE4()
        case 5                                                ''STAGE5 - SETUP WINDOWS AGENT
          call STAGE5()
        case 6                                                ''STAGE6 - SETUP WINDOWS PROBE
          call STAGE6()
        case 7                                                ''STAGE7 - AV MONITORING AND SERVICES
          call STAGE7()
        case 8                                                ''STAGE8 - PATCHING MONITORING AND SERVICES
          call STAGE8()
        case 9                                                ''STAGE9 - BACKUP MONITORING AND SERVICES
          call STAGE9()
      end select
      strSEL = vbnullstring
    wend
    ''END MAINLOOP
    ''------------
  end if
elseif (errRET <> 0) then
  call LOGERR(errRET)
end if
''END SCRIPT
call CLEANUP()
''END SCRIPT
''------------

''SUB-ROUTINES
sub STAGE0()
  ''STAGE 0
  ''DOWNLOAD BASE SOFTWARE DEPLOYMENT SCRIPT
  objOUT.write vbnewline & now & vbtab & " - DOWNLOADING BASE DEPLOYMENT SCRIPT" & vbnewline
  objLOG.write vbnewline & now & vbtab & " - DOWNLOADING BASE DEPLOYMENT SCRIPT" & vbnewline
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/dev/Base_Deployment.vbs", "C:\IT\Scripts", "Base_Deployment.vbs")
  ''EXECUTE BASE DEPLOYMENT SCRIPT
  objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING BASE DEPLOYMENT SCRIPT"
  objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING BASE DEPLOYMENT SCRIPT"
  call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\Base_Deployment.vbs" & chr(34))
end sub

sub STAGE1()
  ''------------REF #6
  ''STAGE1
  ''CHANGE ACTIVE POWER PLAN
  objOUT.write vbnewline & now & vbtab & " - SETTING ACTIVE POWER PLAN : HIGH PERFORMANCE" & vbnewline
  objLOG.write vbnewline & now & vbtab & " - SETTING ACTIVE POWER PLAN : HIGH PERFORMANCE" & vbnewline
  call HOOK("powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c")
  ''DISABLE HIBERNATION
  objOUT.write vbnewline & now & vbtab & " - DISABLING HIBERNATION" & vbnewline
  objLOG.write vbnewline & now & vbtab & " - DISABLING HIBERNATION" & vbnewline
  call HOOK("powercfg –h off")
  ''NETOWRK DISCOVERY
  objOUT.write vbnewline & now & vbtab & " - ENABLING NETWORK DISCOVERY SERVICES" & vbnewline
  objLOG.write vbnewline & now & vbtab & " - ENABLING NETWORK DISCOVERY SERVICES" & vbnewline
  call HOOK("sc config " & chr(34) & "fdPHost" & chr(34) & " start= auto")
  call HOOK("sc start " & chr(34) & "fdPHost" & chr(34))
  call HOOK("sc config " & chr(34) & "FDResPub" & chr(34) & " start= auto")
  call HOOK("sc start " & chr(34) & "FDResPub" & chr(34))
  strSEL = vbnullstring
  if (err.number <> 0) then
    call LOGERR(1)
  end if
end sub

sub STAGE2()
  ''------------REF #6
  ''STAGE2 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''RENAME COMPUTER - REQUIRES RESTART; REQUIRES 'STRNEWPC'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  objOUT.write vbnewline & vbnewline & now & vbtab & "RENAME COMPUTER? (WILL REQUIRE RESTART PRIOR TO CONTINUING, Y / N)" & vbnewline
  objLOG.write vbnewline & vbnewline & now & vbtab & "RENAME COMPUTER? (WILL REQUIRE RESTART PRIOR TO CONTINUING, Y / N)" & vbnewline
  strSEL = objIN.readline
  ''DEFAULT NO REBOOT
  blnRBT = false
  if (ucase(strSEL) = "Y") then
    objOUT.write vbnewline & vbtab & vbtab & "ENTER NEW COMPUTER NAME : " & vbnewline & vbtab & vbtab & _
      "RECOMMENDED FOLLOWING '<CO INITIALS–DEVICE TYPE–NAME>' FORMAT" & vbnewline & vbtab & vbtab
    objLOG.write vbnewline & vbtab & vbtab & "ENTER NEW COMPUTER NAME : " & vbnewline & vbtab & vbtab & _
      "RECOMMENDED FOLLOWING '<CO INITIALS–DEVICE TYPE–NAME>' FORMAT" & vbnewline & vbtab & vbtab
    strNEWPC = objIN.readline
    if (strNEWPC <> vbnullstring) then
      set colCOMP = objWMI.execquery ("select * from Win32_ComputerSystem")
      for each objCOMP in colCOMP
        intERR = objCOMP.rename(strNEWPC)
        if (intERR <> 0) then
          objOUT.write vbnewline & vbtab & " - ERROR RENAMING COMPUTER : " & strNEWPC & vbnewline & vbtab & _
            "PLEASE RESTART AND TRY AGAIN / CHECK PERMISSIONS"
          objLOG.write vbnewline & vbtab & " - ERROR RENAMING COMPUTER : " & strNEWPC & vbnewline & vbtab & _
            "PLEASE RESTART AND TRY AGAIN / CHECK PERMISSIONS"
        elseif (intERR = 0) then
          objOUT.write vbnewline & vbtab & " - SUCCESSFULLY RENAMED COMPUTER : " & strNEWPC & vbnewline & vbtab & _
            "COMPUTER WILL NOW RESTART, PLEASE RUN SCRIPT AGAIN AND SKIP THIS STEP"
          objLOG.write vbnewline & vbtab & " - SUCCESSFULLY RENAMED COMPUTER : " & strNEWPC & vbnewline & vbtab & _
            "COMPUTER WILL NOW RESTART, PLEASE RUN SCRIPT AGAIN AND SKIP THIS STEP"
          blnRBT = true
        end if
      next
      set objCOMP = nothing
      set colCOMP = nothing
      ''STEP TO VERIFY ADMIN USER CREDENTIALS
      objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY DEVICE NAME"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY DEVICE NAME"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PROPERTIES>GIVEN NAME"
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PROPERTIES>GIVEN NAME"
      objOUT.write vbnewline & now & vbtab & " - ENTER NEW CONFIGURED DEVICE NAME"
      objLOG.write vbnewline & now & vbtab & " - ENTER NEW CONFIGURED DEVICE NAME"
      objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY, DEVICE WILL RESTART AFTERWARDS, PLEASE RE-RUN SCRIPT"
      objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY, DEVICE WILL RESTART AFTERWARDS, PLEASE RE-RUN SCRIPT"
      strNUL = objIN.readline
      if (blnRBT) then
        ''RESTART COMPUTER - PROVIDES REASON
        call HOOK("shutdown /r /t 10 /d:p /c " & chr(34) & "AUTO_PANv2 - COMPUTER RENAME : " & strNEWPC & chr(34))
        if (err.number <> 0) then
          call LOGERR(21)
        end if
      end if
    end if
  end if
  ''CLEAR INPUT
  strSEL = vbnullstring
  if (err.number <> 0) then
    call LOGERR(2)
  end if
end sub

sub STAGE3()
  ''------------REF #6
  ''STAGE3 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''PROMPT FOR TYPE OF SETUP (LOCAL / DOMAIN) , REF #16
  objOUT.write vbnewline & vbnewline & now & vbtab & " - (3)STAGE3 - SELECT TYPE OF SETUP"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - (3)STAGE3 - SELECT TYPE OF SETUP"
  objOUT.write vbnewline & vbtab & vbtab & " - (1)STAGE3 - LOCAL RMMTECH ADMIN" & vbnewline & vbtab & vbtab & " - (2)STAGE3 - DOMAIN RMMTECH / JOIN DOMAIN (RESTART REQ.)" & vbnewline & vbtab
  objLOG.write vbnewline & vbtab & vbtab & " - (1)STAGE3 - LOCAL RMMTECH ADMIN" & vbnewline & vbtab & vbtab & " - (2)STAGE3 - DOMAIN RMMTECH / JOIN DOMAIN (RESTART REQ.)" & vbnewline & vbtab
  strSEL = objIN.readline
  if ((ucase(strSEL) = "LOCAL") or (strSEL = "1")) then
    strSEL = "LOCAL"
  elseif ((ucase(strSEL) = "DOMAIN") or (strSEL = "2")) then
    strSEL = "DOMAIN"
  end if
  select case strSEL
    case "LOCAL"
      strDMN = "."
      strTYP = "local"
      objOUT.write vbnewline & vbnewline & vbtab & vbtab & " - (3)STAGE3 - LOCAL RMMTECH (PWD & SVC LOGON)"
      objLOG.write vbnewline & vbnewline & vbtab & vbtab & " - (3)STAGE3 - LOCAL RMMTECH (PWD & SVC LOGON)"
      ''UPDATE RMMTECH USER (LOCAL ONLY) - REQUIRES 'STRPWD'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
      if (strPWD = vbnullstring) then
        objOUT.write vbnewline & vbtab & vbtab & "CREATE AND UPDATE LOCAL RMMTECH USER (Y / N)?" & vbnewline & vbtab & vbtab
        objLOG.write vbnewline & vbtab & vbtab & "CREATE AND UPDATE LOCAL RMMTECH USER (Y / N)?" & vbnewline & vbtab & vbtab
        strSEL = objIN.readline
        if (ucase(strSEL) = "Y") then
          objOUT.write vbnewline & vbtab & vbtab & "ENTER NEW PASSWORD :" & vbnewline & vbtab & vbtab
          objLOG.write vbnewline & vbtab & vbtab & "ENTER NEW PASSWORD :" & vbnewline & vbtab & vbtab
          strPWD = objIN.readline
          if (strPWD <> vbnullstring) then
            ''CREATE RMMTECH USER
            objOUT.write vbnewline & now & vbtab & vbtab & " - CREATING RMMTECH USER"
            objLOG.write vbnewline & now & vbtab & vbtab & " - CREATING RMMTECH USER"
            call HOOK("net user " & chr(34) & "RMMTech" & chr(34) & " " & chr(34) & strPWD & chr(34) & _
              "  /add /active:yes /expires:never /passwordchg:yes /passwordreq:yes /Y")
            ''SET PASSWORD TO NEVER EXPIRE
            objOUT.write vbnewline & now & vbtab & vbtab & " - SETTING RMMTECH PASSWORD TO NEVER EXPIRE"
            objLOG.write vbnewline & now & vbtab & vbtab & " - SETTING RMMTECH PASSWORD TO NEVER EXPIRE"
            call HOOK("wmic useraccount where Name='rmmtech' set PasswordExpires=FALSE")
            ''ADD RMMTECH TO LOCAL ADMINISTRATORS GROUP
            objOUT.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO LOCAL ADMINISTRATORS GROUP"
            objLOG.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO LOCAL ADMINISTRATORS GROUP"
            call HOOK("net localgroup " & chr(34) & "Administrators" & chr(34) & " " & chr(34) & "RMMTech" & chr(34) & " /add")
          end if
        end if
      end if    
    
    case "DOMAIN"
      strTYP = "domain"
      objOUT.write vbnewline & vbnewline & vbtab & vbtab & " - (3)STAGE3 - DOMAIN RMMTECH (PWD & SVC LOGON)"
      objOUT.write vbnewline & vbtab & vbtab & " - RUNNING THIS STAGE FROM A DEVICE OTHER THAN THE AD-DC OR A DOMAIN DEVICE WILL REQUIRE JOINING TO DOMAIN AND REBOOT"
      objLOG.write vbnewline & vbnewline & vbtab & vbtab & " - (3)STAGE3 - DOMAIN RMMTECH (PWD & SVC LOGON)"
      ''UPDATE RMMTECH USER (DOMAIN ONLY) - REQUIRES 'STRPWD'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS , REF #16
      if (strPWD = vbnullstring) then
        objOUT.write vbnewline & vbtab & vbtab & "CREATE AND UPDATE DOMAIN RMMTECH USER (Y / N)?" & vbnewline & vbtab & vbtab
        objLOG.write vbnewline & vbtab & vbtab & "CREATE AND UPDATE DOMAIN RMMTECH USER (Y / N)?" & vbnewline & vbtab & vbtab
        strSEL = objIN.readline
        if (ucase(strSEL) = "Y") then
          objOUT.write vbnewline & vbtab & vbtab & "IS DEVICE ALREADY MEMBER OF DOMAIN (Y / N)?" & vbnewline & vbtab & vbtab
          objLOG.write vbnewline & vbtab & vbtab & "IS DEVICE ALREADY MEMBER OF DOMAIN (Y / N)?" & vbnewline & vbtab & vbtab
          strSEL = objIN.readline
          if (ucase(strSEL) = "Y") then
            objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN :" & vbnewline & vbtab & vbtab
            objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN :" & vbnewline & vbtab & vbtab
            strDMN = objIN.readline
            objOUT.write vbnewline & vbtab & vbtab & "ENTER NEW PASSWORD :" & vbnewline & vbtab & vbtab
            objLOG.write vbnewline & vbtab & vbtab & "ENTER NEW PASSWORD :" & vbnewline & vbtab & vbtab
            strPWD = objIN.readline
            ''CREATE RMMTECH USER
            objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - CREATING RMMTECH USER"
            objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - CREATING RMMTECH USER"
            call HOOK("net user RMMTech " & chr(34) & strPWD & chr(34) & " /add /domain /y")
            wscript.sleep 3000
            ''ADD RMMTECH TO DOMAIN ADMINISTRATORS GROUP
            objOUT.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO DOMAIN GROUPS"
            objLOG.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO DOMAIN GROUPS"
            call HOOK("net group Administrators RMMTech /add /domain")
            call HOOK("net group Domain Admins RMMTech /add /domain")
            call HOOK("net group Enterprise Admins RMMTech /add /domain")
            call HOOK("net group Schema Admins RMMTech /add /domain")
            ''ADD RMMTECH TO LOCAL ADMINISTRATORS GROUP
            objOUT.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO LOCAL ADMINISTRATORS GROUP"
            objLOG.write vbnewline & now & vbtab & vbtab & " - ADDING RMMTECH TO LOCAL ADMINISTRATORS GROUP"
            call HOOK("net localgroup Administrators RMMTech /add /domain")
          elseif (ucase(strSEL) = "N") then
            objOUT.write vbnewline & vbnewline & now & vbtab & vbtab & " - ADDING DEVICE TO DOMAIN (WILL REQUIRE RESTART PRIOR TO CONTINUING)"
            objLOG.write vbnewline & vbnewline & now & vbtab & vbtab & " - ADDING DEVICE TO DOMAIN (WILL REQUIRE RESTART PRIOR TO CONTINUING)"
            ''PROMPT FOR DOMAIN FQDN
            objOUT.write vbnewline & vbtab & vbtab & "ENTER FQDN DOMAIN NAME (MY.DOMAIN.LOCAL) :" & vbnewline & vbtab & vbtab
            objLOG.write vbnewline & vbtab & vbtab & "ENTER FQDN DOMAIN NAME (MY.DOMAIN.LOCAL) :" & vbnewline & vbtab & vbtab
            strDMN = objIN.readline
            ''PROMPT FOR DOMAIN ADMIN USER
            objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER WITH DOMAIN ADMIN (DOMAIN\USER) :" & vbnewline & vbtab & vbtab
            objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER WITH DOMAIN ADMIN (DOMAIN\USER) :" & vbnewline & vbtab & vbtab
            strDUSR = objIN.readline
            ''PROMPT FOR DOMAIN ADMIN USER PASSWORD
            objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER WITH DOMAIN ADMIN PASSWORD :" & vbnewline & vbtab & vbtab
            objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER WITH DOMAIN ADMIN PASSWORD :" & vbnewline & vbtab & vbtab
            strDPWD = objIN.readline
            ''CREATE DN PATH TO DOMAIN COMPUTERS CONTAINER
            strOU = "CN=Computers;"
            for x = 0 to ubound(split(strDMN, "."))
              if (x < ubound(split(strDMN, "."))) then
                strOU = strOU & "DC=" & (split(strDMN, ".")(x)) & ";"
              elseif (x = ubound(split(strDMN, "."))) then
                strOU = strOU & "DC=" & (split(strDMN, ".")(x))
              end if
            next
            ''JOIN COMPUTER TO DOMAIN
            strJOIN = "wmic /interactive:off ComputerSystem Where name=" & chr(34) & "%computername%" & chr(34) & " call JoinDomainOrWorkgroup FJoinOptions=3 Name=" & _
              chr(34) & strDMN & chr(34) & " UserName=" & chr(34) & strDUSR & chr(34) & " Password=" & chr(34) & strDPWD & chr(34) & " AccountOU=" & chr(34) & strOU & chr(34)
            call HOOK(strJOIN)
          end if
        end if
      end if
  end select
  ''GRANT 'LOGON AS A SERVICE' TO RMMTECH USER
  ''DOWNLOAD SERVICE LOGON SCRIPT : SVCPERM , REF #16
  objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SERVICE LOGON SCRIPT : SVCPERM"
  objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SERVICE LOGON SCRIPT : SVCPERM"
  call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/SVCperm.vbs", "C:\IT\Scripts", "SVCperm.vbs")
  if (objFSO.fileexists("c:\IT\Scripts\SVCperm.vbs")) then
    ''EXECUTE SERVICE LOGON SCRIPT : SVCPERM , REF #16
    objOUT.write vbnewline & now & vbtab & vbtab & " - EXECUTING SERVICE LOGON SCRIPT : SVCPERM"
    objLOG.write vbnewline & now & vbtab & vbtab & " - EXECUTING SERVICE LOGON SCRIPT : SVCPERM"
    call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\SVCperm.vbs" & chr(34) & " " & chr(34) & strDMN & "\RMMTech" & chr(34) & " " & chr(34) & strTYP & chr(34))
    objOUT.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : RMMTECH"
    objLOG.write vbnewline & now & vbtab & vbtab & " - LOGON AS SERVICE GRANTED : RMMTECH"
  elseif (not objFSO.fileexists("c:\IT\Scripts\SVCperm.vbs")) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
    call LOGERR(32)
  end if 
  ''STEP TO VERIFY ADMIN USER CREDENTIALS
  objOUT.write vbnewline & vbnewline & now & vbtab & " - (3)STAGE3 - COMPLETE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - (3)STAGE3 - COMPLETE"
  objOUT.write vbnewline & now & vbtab & " - PLEASE VERIFY ADMIN USER CREDENTIALS"
  objLOG.write vbnewline & now & vbtab & " - PLEASE VERIFY ADMIN USER CREDENTIALS"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>DEFAULTS>APPLIANCE SETTINGS>CREDENTIALS"
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>DEFAULTS>APPLIANCE SETTINGS>CREDENTIALS"
  objOUT.write vbnewline & now & vbtab & " - ENTER RMMTECH AND RMMTECH PASSWORD, CHECK BOX UNDER 'PROPAGATE'"
  objLOG.write vbnewline & now & vbtab & " - ENTER RMMTECH AND RMMTECH PASSWORD, CHECK BOX UNDER 'PROPAGATE'"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PROPERTIES>CREDENTIALS"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PROPERTIES>CREDENTIALS"
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  strSEL = vbnullstring
  if (err.number <> 0) then
    call LOGERR(3)
  end if
end sub

sub STAGE4()
  ''------------REF #6
  ''STAGE4 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''INSTALL AND CONFIGURE SNMP - REQUIRES 'STRTRP', 'STRSNMP'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  objOUT.write vbnewline & vbnewline & vbtab & "INSTALLING AND CONFIGURING SNMP"
  objLOG.write vbnewline & vbnewline & vbtab & "INSTALLING AND CONFIGURING SNMP"
  objOUT.write vbnewline & vbtab & vbtab & "ENTER WINDOWS SOFTWARE PROBE IP / SNMP MONITOR AGENT IP (SEPARATE MULTIPLE ENTRIES WITH ',') :" & vbnewline
  objLOG.write vbnewline & vbtab & vbtab & "ENTER WINDOWS SOFTWARE PROBE IP / SNMP MONITOR AGENT IP (SEPARATE MULTIPLE ENTRIES WITH ',') :" & vbnewline
  strTRP = objIN.readline
  objOUT.write vbnewline & vbtab & vbtab & "ENTER SNMP COMMUNITY STRING (USE '<CO INITIALS>SNMP'; DO NOT USE 'PUBLIC') :" & vbnewline
  objLOG.write vbnewline & vbtab & vbtab & "ENTER SNMP COMMUNITY STRING (USE '<CO INITIALS>SNMP'; DO NOT USE 'PUBLIC') :" & vbnewline
  strSNMP = objIN.readline
  if ((strTRP <> vbnullstring) and (strSNMP <> vbnullstring)) then
    ''DOWNLOAD SNMP SETUP : SNMPPARAM, REF #6 , FIXES #15
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SNMP SETUP : SNMPPARAM"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING SNMP SETUP : SNMPPARAM"
    call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/SNMPparam.vbs", "C:\IT\Scripts", "SNMPparam.vbs")
    if (objFSO.fileexists("c:\IT\Scripts\SNMPparam.vbs")) then
      ''INSTALL SNMP VIA SNMPPARAM , REF #6 , FIXES #15
      objOUT.write vbnewline & now & vbtab & vbtab & " - SNMP SETUP : SNMPPARAM"
      objLOG.write vbnewline & now & vbtab & vbtab & " - SNMP SETUP : SNMPPARAM"
      call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\SNMPparam.vbs" & chr(34) & _
        " " & chr(34) & "modify" & chr(34) & " " & chr(34) & strSNMP & chr(34) & " " & chr(34) & strTRP & chr(34))
    elseif (not objFSO.fileexists("c:\IT\Scripts\SNMPparam.vbs")) then
      objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
      objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
      call LOGERR(41)
    end if
    objOUT.write vbnewline & now & vbtab & "SNMP CONFIGURATIONS COMPLETED"
    objLOG.write vbnewline & now & vbtab & "SNMP CONFIGURATIONS COMPLETED"
    objOUT.write vbnewline & now & vbtab & "PLEASE REVIEW SNMP CONFIGURATIONS :"
    objLOG.write vbnewline & now & vbtab & "PLEASE REVIEW SNMP CONFIGURATIONS :"    
    call HOOK("reg query " & chr(34) & "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters" & chr(34) & " /s")
    if (err.number <> 0) then
      call LOGERR(42)
    end if 
    ''STEP TO VERIFY SNMP MONITORING
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY SNMP MONITORING"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY SNMP MONITORING"
    objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>DEFAULTS>BACKUP AND SNMP DEFAULTS;"
    objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>DEFAULTS>BACKUP AND SNMP DEFAULTS;"
    objOUT.write vbnewline & now & vbtab & " - DISABLE THE 'SYSTEM DEFAULT' SNMP PROFILE, USE 'ADD SNMP CREDENTIALS' TO CREATE NEW SNMPv1 PROFILE, USE CUSTOMER SNMP SETTINGS"
    objLOG.write vbnewline & now & vbtab & " - DISABLE THE 'SYSTEM DEFAULT' SNMP PROFILE, USE 'ADD SNMP CREDENTIALS' TO CREATE NEW SNMPv1 PROFILE, USE CUSTOMER SNMP SETTINGS"
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONFIGURE DEVICE FOR SNMP MONITORING"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONFIGURE DEVICE FOR SNMP MONITORING"
    objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>MONITORING OPTIONS, CHECK 'USE SNMP', SETTINGS FROM PREVIOUS STEP SHOULD BE POPULATED"
    objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>MONITORING OPTIONS, CHECK 'USE SNMP', SETTINGS FROM PREVIOUS STEP SHOULD BE POPULATED"
    objOUT.write vbnewline & vbnewline & now & vbtab & " - RE-APPLY '<DEVICE CLASS> - WINDOWS' TEMPLATE IF NEEDED"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - RE-APPLY '<DEVICE CLASS> - WINDOWS' TEMPLATE IF NEEDED"
    objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING."
    objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING."
    objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    strNUL = objIN.readline
  end if
  strSEL = vbnullstring
  if (err.number <> 0) then
    call LOGERR(4)
  end if
end sub

sub STAGE5()
  ''------------REF #6
  ''STAGE5 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''INSTALL WINDOWS AGENT - REQUIRES 'STRCID', 'STRCNAM'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  if (strAGT = vbnullstring) then
    objOUT.write vbnewline & vbnewline & vbtab & "INSTALL WINDOWS AGENT (Y / N)?" & vbnewline
    objLOG.write vbnewline & vbnewline & vbtab & "INSTALL WINDOWS AGENT (Y / N)?" & vbnewline
    strSEL = objIN.readline
    if (ucase(strSEL) = "Y") then
      ''CUSTOMER ID
      objOUT.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER ID :" & vbnewline
      objLOG.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER ID :" & vbnewline
      strCID = objIN.readline
      ''CUSTOMER NAME
      objOUT.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER NAME :" & vbnewline
      objLOG.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER NAME :" & vbnewline
      strCNAM = objIN.readline
      ''SERVER ADDRESS
      objOUT.write vbnewline & vbtab & vbtab & "ENTER SERVER ADDRESS ('ncentral.cwitsupport.com') :" & vbnewline
      objLOG.write vbnewline & vbtab & vbtab & "ENTER SERVER ADDRESS ('ncentral.cwitsupport.com') :" & vbnewline
      strSRV = objIN.readline
      if (strSRV = vbnullstring) then
        strSRV = "ncentral.cwitsupport.com"
      end if
      if ((strCID <> vbnullstring) and (strCNAM <> vbnullstring)) then
        ''DOWNLOAD WINDOWS AGENT SETUP : RE-AGENT , FIXES #7
        objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING WINDOWS AGENT SETUP : RE-AGENT"
        objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING WINDOWS AGENT SETUP : RE-AGENT"
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/CW_MSI/master/exe_reagent.vbs", "C:\IT\Scripts", "exe_reagent.vbs")
        if (objFSO.fileexists("c:\IT\Scripts\exe_reagent.vbs")) then
          ''INSTALL WINDOWS AGENT VIA RE-AGENT , FIXES #7
          objOUT.write vbnewline & now & vbtab & vbtab & " - WINDOWS AGENT SETUP : RE-AGENT, PLEASE WAIT FOR 'MSIEXEC' PROCESSES TO COMPLETE"
          objLOG.write vbnewline & now & vbtab & vbtab & " - WINDOWS AGENT SETUP : RE-AGENT, PLEASE WAIT FOR 'MSIEXEC' PROCESSES TO COMPLETE"
          call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\exe_reagent.vbs" & chr(34) & _
            " " & chr(34) & strCID & chr(34) & " " & chr(34) & strCNAM & chr(34) & " " & chr(34) & strSRV & chr(34))
        elseif (not objFSO.fileexists("c:\IT\Scripts\exe_reagent.vbs")) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
          objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
          call LOGERR(51)
        end if
      end if
      ''STEP TO VERIFY WINDOWS AGENT / MONITORING
      objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY IMPORT / WINDOWS AGENT MONITORING"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY IMPORT / WINDOWS AGENT MONITORING"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. THIS NEW DEVICE SHOULD SHOW UP WITHIN MINUTES AS THE AGENT CHECKS IN."
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. THIS NEW DEVICE SHOULD SHOW UP WITHIN MINUTES AS THE AGENT CHECKS IN."
      objOUT.write vbnewline & vbnewline & now & vbtab & " - CONFIGURE 'CONTRACT SERVICE CODE' OR USE 'AUTOMATION CODE'"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - CONFIGURE 'CONTRACT SERVICE CODE' OR USE 'AUTOMATION CODE'"
      objOUT.write vbnewline & now & vbtab & " - 'CONTRACT SERVICE CODES' ARE SETUP AS FILTERS IN N-CENTRAL AND ARE USEFUL FOR IDENTIFYING CUSTOMER DEVICES,"
      objLOG.write vbnewline & now & vbtab & " - 'CONTRACT SERVICE CODES' ARE SETUP AS FILTERS IN N-CENTRAL AND ARE USEFUL FOR IDENTIFYING CUSTOMER DEVICES,"
      objOTU.write vbnewline & now & vbtab & " - 'AUTOMATION CODES' WILL AUTOMATICALLY ASSIGN AV, PATCHING, AND MSP BACKUPS PER CONTRACT 'SERVICE CODE' SOP,"
      objOUT.write vbnewline & now & vbtab & " - 'AUTOMATION CODES' WILL AUTOMATICALLY ASSIGN AV, PATCHING, AND MSP BACKUPS PER CONTRACT 'SERVICE CODE' SOP,"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>CUSTOM DETAILS>SERVICE CODE CUSTOM DEVICE PROPERTY."
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>CUSTOM DETAILS>SERVICE CODE CUSTOM DEVICE PROPERTY."
      objOUT.write vbnewline & vbnewline & now & vbtab & " - RE-APPLY '<DEVICE CLASS> - WINDOWS' TEMPLATE IF NEEDED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - RE-APPLY '<DEVICE CLASS> - WINDOWS' TEMPLATE IF NEEDED"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING>SERVICE TEMPLATES."
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING>SERVICE TEMPLATES."
      objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
      objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
      strNUL = objIN.readline
    end if
  end if
  if (err.number <> 0) then
    call LOGERR(5)
  end if
  ''CLEAR VARIABLES
  strSEL = vbnullstring
  strCID = vbnullstring
  strCNAM = vbnullstring
  strSRV = vbnullstring
end sub

sub STAGE6()
  ''------------REF #6
  ''STAGE6 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS - NEED DOMAIN / WORKGROUP SELECTION
  ''INSTALL PROBE - REQUIRES 'STRCID', 'STRCNAM', 'STRDMN', 'STRDUSR', 'STRDPWD'; REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  if (strPRB = vbnullstring) then
    objOUT.write vbnewline & vbnewline & vbtab & "INSTALL WINDOWS PROBE (Y / N)?" & vbnewline
    objLOG.write vbnewline & vbnewline & vbtab & "INSTALL WINDOWS PROBE (Y / N)?" & vbnewline
    strSEL = objIN.readline
    if (ucase(strSEL) = "Y") then
      ''PROBE TYPE - Workgroup_Windows / Network_Windows
      objOUT.write vbnewline & vbtab & vbtab & "SELECT PROBE TYPE : (1) Workgroup_Windows / (2) Network_Windows :" & vbnewline
      objLOG.write vbnewline & vbtab & vbtab & "SELECT PROBE TYPE : (1) Workgroup_Windows / (2) Network_Windows :" & vbnewline
      strTYP = objIN.readline
      if ((strTYP = 1) or (lcase(strTYP) = "workgroup")) then
        strTYP = "Workgroup_Windows"
      elseif ((strTYP = 2) or (lcase(strTYP) = "network")) then
        strTYP = "Network_Windows"
      elseif ((strTYP <> 1) and (strTYP <> 2)) then
        call LOGERR(61)
      end if
      if (errRET <> 61) then
        ''CUSTOMER ID
        objOUT.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER ID :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER ID :" & vbnewline
        strCID = objIN.readline
        ''CUSTOMER NAME
        objOUT.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER NAME :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER CUSTOMER NAME :" & vbnewline
        strCNAM = objIN.readline
        ''DOMAIN
        objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN (DO NOT INCLUDE '\', MAY BE BLANK IF WORKGROUP) :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN (DO NOT INCLUDE '\', MAY BE BLANK IF WORKGROUP) :" & vbnewline
        strDMN = objIN.readline
        if (strTYP = "Workgroup_Windows") then
          strDMN = "."
        end if
        if (instr(1, strDMN, "\")) then
          strDMN = replace(strDMN, "\", vbnullstring)
        end if
        ''DOMAIN USER
        objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER (DO NOT INCLUDE 'DOMAIN\') :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER (DO NOT INCLUDE 'DOMAIN\') :" & vbnewline
        strDUSR = objIN.readline
        ''DOMAIN USER PASSWORD
        objOUT.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER PASSWORD :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER DOMAIN USER PASSWORD :" & vbnewline
        strDPWD = objIN.readline
        ''SERVER ADDRESS
        objOUT.write vbnewline & vbtab & vbtab & "ENTER SERVER ADDRESS ('ncentral.cwitsupport.com') :" & vbnewline
        objLOG.write vbnewline & vbtab & vbtab & "ENTER SERVER ADDRESS ('ncentral.cwitsupport.com') :" & vbnewline
        strSRV = objIN.readline
        if (strSRV = vbnullstring) then
          strSRV = "ncentral.cwitsupport.com"
        end if
        if ((strCID <> vbnullstring) and (strCNAM <> vbnullstring) and _
          (strDMN <> vbnullstring) and (strDUSR <> vbnullstring) and (strDPWD <> vbnullstring)) then
            ''DOWNLOAD WINDOWS PROBE SETUP : RE-PROBE , FIXES #7
            objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING WINDOWS PROBE SETUP : RE-PROBE"
            objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING WINDOWS PROBE SETUP : RE-PROBE"
            call FILEDL("https://raw.githubusercontent.com/CW-Khristos/CW_MSI/master/exe_reprobe.vbs", "C:\IT\Scripts", "exe_reprobe.vbs")
            if (objFSO.fileexists("c:\IT\Scripts\exe_reprobe.vbs")) then
              ''INSTALL WINDOWS PROBE VIA RE-PROBE , FIXES #7
              objOUT.write vbnewline & now & vbtab & vbtab & " - WINDOWS PROBE SETUP : RE-PROBE, PLEASE WAIT FOR 'MSIEXEC' PROCESSES TO COMPLETE"
              objLOG.write vbnewline & now & vbtab & vbtab & " - WINDOWS PROBE SETUP : RE-PROBE, PLEASE WAIT FOR 'MSIEXEC' PROCESSES TO COMPLETE"
              call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\exe_reprobe.vbs" & chr(34) & _
                " " & chr(34) & strCID & chr(34) & " " & chr(34) & strCNAM & chr(34) & " " & chr(34) & strTYP & chr(34) & _
                " " & chr(34) & strDMN & "\" & strDUSR & chr(34) & " " & chr(34) & strDPWD & chr(34) & " " & chr(34) & strSRV & chr(34))
            elseif (not objFSO.fileexists("c:\IT\Scripts\exe_reprobe.vbs")) then
              objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
              objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
              call LOGERR(62)
            end if
        end if
      end if
      ''STEP TO VERIFY WINDOWS PROBE / MONITORING
      objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY WINDOWS PROBE / MONITORING"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY WINDOWS PROBE / MONITORING"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'WINDOWS PROBE - <DEVICE CLASS>' TEMPLATE IF NEEDED"
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'WINDOWS PROBE - <DEVICE CLASS>' TEMPLATE IF NEEDED"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>PROBES, USE 'TRANSFER TASKS' TO ASSIGN DEVICE MONITORING TO PROBE"
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>PROBES, USE 'TRANSFER TASKS' TO ASSIGN DEVICE MONITORING TO PROBE"
      objOUT.write vbnewline & vbnewline & now & vbtab & " - IF DESIRED, ENABLE PROBE AS THE AV DEFENDER UPDATE SERVER. " & _ 
        "(CONFIGURED CLIENTS WILL USE THIS DEVICE FOR AV UPDATES)"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - IF DESIRED, ENABLE PROBE AS THE AV DEFENDER UPDATE SERVER. " & _ 
        "(CONFIGURED CLIENTS WILL USE THIS DEVICE FOR AV UPDATES)"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>SECURITY MANAGER>UPDATE SERVERS>ENABLE"
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>SECURITY MANAGER>UPDATE SERVERS>ENABLE"
      objOUT.write vbnewline & vbnewline & now & vbtab & " - IF DESIRED, ENABLE PROBE AS THE PATCH CACHE REPOSITORY. " & _ 
        "(CONFIGURED CLIENTS WILL USE THIS DEVICE FOR PATCH UPDATES. THIS REQUIRES ~20GB FREE SPACE AVAILABLE)"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - IF DESIRED, ENABLE PROBE AS THE PATCH CACHE REPOSITORY. " & _ 
        "(CONFIGURED CLIENTS WILL USE THIS DEVICE FOR PATCH UPDATES. THIS REQUIRES ~20GB FREE SPACE AVAILABLE)"
      objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>PROBES>PATCH CACHING>ENABLE"
      objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ADMINISTRATION>PROBES>PATCH CACHING>ENABLE"
      objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
      objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
      strNUL = objIN.readline
    end if
  end if
  if (err.number <> 0) then
    call LOGERR(6)
  end if
  ''CLEAR VARIABLES
  strSEL = vbnullstring
  strCID = vbnullstring
  strCNAM = vbnullstring
  strTYP = vbNullString
  strDMN = vbNullString
  strDUSR = vbnullstring
  strDPWD = vbnullstring
  strSRV = vbnullstring
end sub

sub STAGE7()
  ''------------REF #6
  ''STAGE7 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''INSTALL AV DEFENDER - REQUIRES 'ENTER' TO RESUME AFTER PAUSE
  ''DOWNLOAD AND INSTALL AV DEFENDER, REF #6 , FIXES #14
  objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING AV DEFENDER"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING AV DEFENDER"
  objOUT.write vbnewline & now & vbtab & " - PLEASE ENABLE AV DEFENDER VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>SECURITY MANAGER"
  objLOG.write vbnewline & now & vbtab & " - PLEASE ENABLE AV DEFENDER VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>SECURITY MANAGER"
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  'call FILEDL(strAVDdl,"AVDefender.exe")
  ''STEP TO VERIFY AV DEFENDER / MONITORING, REF #6 , FIXES #14
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY AV DEFENDER / MONITORING"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY AV DEFENDER / MONITORING"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'AV DEFENDER REQUIRED SERVICES - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'AV DEFENDER REQUIRED SERVICES - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED AV DEFENDER PROFILE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED AV DEFENDER PROFILE"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>SECURITY MANAGER."
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>SECURITY MANAGER."
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  if (err.number <> 0) then
    call LOGERR(7)
  end if
end sub

sub STAGE8()
  ''------------REF #6
  ''STAGE8 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''ENABLE PATCHING - REQUIRES 'ENTER' TO RESUME AFTER PAUSE
  ''PAUSE TO ENABLE PATCHING, REF #6 , FIXES #13
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE ENABLE PATCHING VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PATCH MANAGEMENT"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE ENABLE PATCHING VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PATCH MANAGEMENT"
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  ''STEP TO VERIFY PATCHING / MONITORING, REF #6 , FIXES #13
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY PATCHING / MONITORING"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY PATCHING / MONITORING"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'PATCH MANAGEMENT - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>MONITORING. RE-APPLY 'PATCH MANAGEMENT - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED PATCH PROFILE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED PATCH PROFILE"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PATCH MANAGEMENT."
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>ALL DEVICES>DEVICE DETAILS>SETTINGS>PATCH MANAGEMENT." 
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  if (err.number <> 0) then
    call LOGERR(8)
  end if
end sub

sub STAGE9()
  ''------------REF #6
  ''STAGE9 - REQUIRES TECHNICIAN INPUT / PASSED PARAMETERS
  ''ENABLE MSP BACKUP - REQUIRES 'ENTER' TO RESUME AFTER PAUSE
  ''DOWNLOAD AND INSTALL MSP BACKUP, REF #6 , FIXES #12
  objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING MSP BACKUP"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING MSP BACKUP"
  objOUT.write vbnewline & now & vbtab & " - ONCE INSTALLED, PLEASE ENABLE MSP BACKUP VIA N-CENTRAL>DEVICE DETAILS>SETTINGS>BACKUP MANAGEMENT"
  objLOG.write vbnewline & now & vbtab & " - ONCE INSTALLED, PLEASE ENABLE MSP BACKUP VIA N-CENTRAL>DEVICE DETAILS>SETTINGS>BACKUP MANAGEMENT"
  call FILEDL("https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe", "C:\IT", "MSPBackup.exe")
  call HOOK("c:\IT\MSPBackup.exe")
  ''STEP TO VERIFY MSP BACKUP / MONITORING, REF #6 , FIXES #12
  objOUT.write vbnewline & vbnewline & now & vbtab & " - ONCE CONFIGURED, PLEASE VERIFY MSP BACKUP / MONITORING"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - ONCE CONFIGURED, PLEASE VERIFY MSP BACKUP / MONITORING"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>DEVICE DETAILS>MONITORING. RE-APPLY 'MSP BAKCUP MANAGER - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>DEVICE DETAILS>MONITORING. RE-APPLY 'MSP BACKUP MANAGER - <DEVICE CLASS>' TEMPLATE IF NEEDED"
  objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED MSP BACKUP SCHEDULE PROFILE"
  objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY CONFIGURED MSP BACKUP SCHEDULE PROFILE"
  objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>DEVICE DETAILS>SETTINGS>BACKUP MANAGEMENT."
  objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>DEVICE DETAILS>SETTINGS>BACKUP MANAGEMENT."
  objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
  strNUL = objIN.readline
  ''PAUSE TO ENABLE MSP BACKUP LOCAL SPEEDVAULT
  objOUT.write vbnewline & vbtab & "ENABLE MSP BACKUP LSV (Y / N)?" & vbnewline
  objLOG.write vbnewline & vbtab & "ENABLE MSP BACKUP LSV (Y / N)?" & vbnewline
  strLSV = objIN.readline
  if (lcase(strLSV) = "y") then
    ''STEP TO CONNECT LOCAL SPEEDVAULT DRIVE
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONNECT MSP BACKUP LOCAL SPEEDVAULT DRIVE"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONNECT MSP BACKUP LOCAL SPEEDVAULT DRIVE"
    objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    strNUL = objIN.readline
    ''REQUEST LOCAL SPEEDVAULT PATH
    objOUT.write vbnewline & vbnewline & now & vbtab & " - ENTER LOCAL SPEEDVAULT PATH : " & vbnewline
    objLOG.write vbnewline & vbnewline & now & vbtab & " - ENTER LOCAL SPEEDVAULT PATH : " & vbnewline
    strLSVL = objIN.readline
    ''REQUEST RMMTECH CREDENTIALS FOR LOCAL SPEEDVAULT
    objOUT.write vbnewline & vbnewline & now & vbtab & " - ENTER RMMTECH USERNAME FOR LSV ACCESS (INCLUDE 'DOMAIN\') : " & vbnewline
    objLOG.write vbnewline & vbnewline & now & vbtab & " - ENTER RMMTECH USERNAME FOR LSV ACCESS (INCLUDE 'DOMAIN\') : " & vbnewline
    strLSVU = objIN.readline
    if (instr(1, strLSVU, "\")) then
      strOPT = "domain"
    elseif (instr(1, strLSVU, "\") = 0) then
      strOPT = "local"
    end if
    objOUT.write vbnewline & vbnewline & now & vbtab & " - ENTER RMMTECH PASSWORD FOR LSV ACCESS : " & vbnewline
    objLOG.write vbnewline & vbnewline & now & vbtab & " - ENTER RMMTECH PASSWORD FOR LSV ACCESS : " & vbnewline
    strLSVP = objIN.readline
    ''SET MSP BACKUP LOCAL SPEEDVAULT SETTINGS, REF #6 , FIXES #12
    objOUT.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP LOCAL SPEEDVAULT SETTINGS"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP LOCAL SPEEDVAULT SETTINGS"
    call HOOK("C:\Program Files\Backup Manager\ClientTool.exe control.setting.modify " & _
      "-name LocalSpeedVaultEnabled -value 1 -name LocalSpeedVaultLocation -value " & chr(34) & strLSVL & chr(34) & _
      " -name LocalSpeedVaultPassword -value " & chr(34) & strLSVP & chr(34) & " -name LocalSpeedVaultUser -value " & chr(34) & strLSVU & chr(34))
    if (err.number <> 0) then
      call LOGERR(91)
    end if
    ''RESTRICT MSP BACKUP LOCAL SPEEDVAULT PERMISSIONS
    objOUT.write vbnewline & vbnewline & now & vbtab & " - RESTRICTING MSP BACKUP LOCAL SPEEDVAULT PERMISSIONS (BACKUP SERVICE WILL RESTART)"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - RESTRICTING MSP BACKUP LOCAL SPEEDVAULT PERMISSIONS (BACKUP SERVICE WILL RESTART)"
    if ((strLSVL <> vbnullstring) and _
      (strLSVU <> vbnullstring) and (strLSVP <> vbnullstring)) then
        ''DOWNLOAD LSV PERMISSIONS SETUP : LSVPERM, REF #6 , FIXES #12
        objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING LSV PERMISSIONS SETUP : LSVPERM"
        objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOADING LSV PERMISSIONS SETUP : LSVPERM"
        call FILEDL("https://raw.githubusercontent.com/CW-Khristos/scripts/master/MSP%20Backups/LSVperm.vbs", "C:\IT\Scripts", "LSVperm.vbs")
        if (objFSO.fileexists("c:\IT\Scripts\LSVperm.vbs")) then
          ''RESTRICT LSV PERMISSIONS VIA LSVPERM, REF #6 , FIXES #12
          objOUT.write vbnewline & now & vbtab & vbtab & " - RESTRICT LSV PERMISSIONS SETUP : LSVPERM"
          objLOG.write vbnewline & now & vbtab & vbtab & " - RESTRICT LSV PERMISSIONS SETUP : LSVPERM"
          call HOOK("cscript.exe //nologo " & chr(34) & "c:\IT\Scripts\LSVperm.vbs" & chr(34) & " " & chr(34) & strLSVL & chr(34) & " " & chr(34) & strLSVU & chr(34) & _
            " " & chr(34) & strLSVP &chr(34) & " " & chr(34) & strOPT & chr(34))
        elseif (not objFSO.fileexists("c:\IT\Scripts\LSVperm.vbs")) then
          objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
          objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD UNSUCCESSFUL"
          call LOGERR(92)
        end if
        if (err.number <> 0) then
          call LOGERR(93)
        end if
    end if
    ''STEP TO VERIFY LOCAL SPEEDVAULT SETTINGS / MONITORING
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP LOCAL SPEEDVAULT SETTINGS"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP LOCAL SPEEDVAULT SETTINGS"
    objOUT.write vbnewline & now & vbatb & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>LOCAL SPEEDVAULT"
    objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>LOCAL SPEEDVAULT"
    objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    strNUL = objIN.readline
  end if
  ''PAUSE TO ENABLE MSP BACKUP ARCHIVES, REF #6 , FIXES #12
  objOUT.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES (Y / N)?" & vbnewline
  objLOG.write vbnewline & vbtab & "ENABLE MSP BACKUP ARCHIVES (Y / N)?" & vbnewline
  strARC = objIN.readline
  if (lcase(strARC) = "y") then
    objOUT.write vbnewline & vbtab & "SELECT MSP BACKUP ARCHIVE SCHEDULE : "
    objLOG.write vbnewline & vbtab & "SELECT MSP BACKUP ARCHIVE SCHEDULE : "
    objOUT.write vbnewline & vbtab & "(1) - 'DEFAULT' - 1ST & 15TH OF EVERY MONTH, AFTER 10PM"
    objLOG.write vbnewline & vbtab & "(1) - 'DEFAULT' - 1ST & 15TH OF EVERY MONTH, AFTER 10PM"
    objOUT.write vbnewline & vbtab & "(2 - WIP, NOT AUTOMATED) - 'CUSTOM' - ENTER OPTIONS FOR A CUSTOM ARCHIVE SCHEDULE" & vbnewline
    objLOG.write vbnewline & vbtab & "(2 - WIP, NOT AUTOMATED) - 'CUSTOM' - ENTER OPTIONS FOR A CUSTOM ARCHIVE SCHEDULE" & vbnewline
    strARC = objIN.readline
    select case strARC
      case 1                    ''SET DEFAULT 'CW_DEFAULT_MSPARCHIVE" ARCHIVING SCHEDULE, REF #6 , FIXES #12
        objOUT.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
        objLOG.write vbnewline & vbnewline & now & vbtab & " - APPLYING MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
        call HOOK("C:\Program Files\Backup Manager\ClientTool.exe control.archiving.add -name " & chr(34) & "CW_DEFAULT_MSPARCHIVE" & chr(34) & _
          " -active 1 -datasources All -days-of-month 1,15 -months All -time 22:00")
      case 2
        objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONFIGURE MSP BACKUP ARCHIVE SCHEDULE '<CO>_<DEVICE>_MSPARCHIVE'"
        objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE CONFIGURE MSP BACKUP ARCHIVE SCHEDULE '<CO>_<DEVICE>_MSPARCHIVE'"
        objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
        objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
        'call HOOK("C:\Program Files\Backup Manager\ClientTool.exe control.archiving.add -name " & chr(34) & "CW_DEFAULT_MSPARCHIVE" & chr(34) & _
        '  " -active 1 -datasources All -days-of-month 1,15 -months All -time 22:00")
    end select
    if (err.number <> 0) then
      call LOGERR(94)
    end if
    ''STEP TO VERIFY MSP BACKUP ARCHIVING SCHEDULE
    objOUT.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - PLEASE VERIFY MSP BACKUP ARCHIVE SCHEDULE 'CW_DEFAULT_MSPARCHIVE'"
    objOUT.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
    objLOG.write vbnewline & now & vbtab & " - VIA N-CENTRAL>CUSTOMER>CONFIGURATION>BACKUP MANAGER>MSP BACKUPS>DASHBOARD>LAUNCH BACKUP CLIENT>PREFERENCES>ARCHIVING"
    objOUT.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    objLOG.write vbnewline & now & vbtab & " - PRESS 'ENTER' WHEN READY"
    strNUL = objIN.readline
  end if
  ''DOWNLOAD AND INSTALL MSP BACKUP VIRTUAL DRIVE, REF #6 , FIXES #12
  objOUT.write vbnewline & vbtab & "INSTALL MSP BACKUP VIRTUAL DRIVE (THIS WILL USE DRIVE B:) (Y / N)?" & vbnewline
  objLOG.write vbnewline & vbtab & "INSTALL MSP BACKUP VIRTUAL DRIVE (THIS WILL USE DRIVE B:) (Y / N)?" & vbnewline
  strMSPVD = objIN.readline
  if (ucase(strMSPVD) = "Y") then
    objOUT.write vbnewline & vbtab & "SELECT MSP BACKUP VIRTUAL DRIVE URL : (1) - (X86) / (2) - (X64)" & vbnewline
    objLOG.write vbnewline & vbtab & "SELECT MSP BACKUP VIRTUAL DRIVE URL : (1) - (X86) / (2) - (X64)" & vbnewline
    strMSPVDdl = objIN.readline
  end if
  ''SELECT URL
  select case strMSPVDdl
    case 1                    ''(x86) DOWNLOAD URL
      strMSPVDdl = "http://cdn.cloudbackup.management/maxdownloads/mxb-vd-windows-x86.exe"
    case 2                    ''(x64) DOWNLOAD URL
      strMSPVDdl = "http://cdn.cloudbackup.management/maxdownloads/mxb-vd-windows-x64.exe"
  end select
  if (strMSPVDdl <> vbnullstring) then
    objOUT.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING MSP BACKUP VIRTUAL DRIVE"
    objLOG.write vbnewline & vbnewline & now & vbtab & " - DOWNLOADING MSP BACKUP VIRTUAL DRIVE"
    objOUT.write vbnewline & now & vbtab & " - ONCE INSTALLED PLEASE EDUCATE CUSTOMER ON USE"
    objLOG.write vbnewline & now & vbtab & " - ONCE INSTALLED PLEASE EDUCATE CUSTOMER ON USE"
    ''DOWNLOAD MSP BACKUP VIRTUAL DRIVE
    call FILEDL(strMSPVDdl, "C:\IT", "MSPBackupVD.exe")
    ''INSTALL MSP BACKUP VIRTUAL DRIVE
    call HOOK("C:\IT\MSPBackupVD.exe")
    if (err.number <> 0) then
      call LOGERR(95)
    end if
  end if
end sub

sub FILEDL(strURL, strDL, strFILE)                          ''CALL HOOK TO DOWNLOAD FILE FROM URL , 'ERRRET'=11
  strSAV = vbnullstring
  ''SET DOWNLOAD PATH
  strSAV = strDL & "\" & strFILE
  objOUT.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  objLOG.write vbnewline & now & vbtab & vbtab & vbtab & "HTTPDOWNLOAD-------------DOWNLOAD : " & strURL & " : SAVE AS :  " & strSAV
  ''ADD WINHTTP SECURE CHANNEL TLS REGISTRY KEYS
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:32")
  call HOOK("reg add " & chr(34) & "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" & chr(34) & _
    " /f /v DefaultSecureProtocols /t REG_DWORD /d 0x00000A00 /reg:64")
  ''CHECK IF FILE ALREADY EXISTS
  if objFSO.fileexists(strSAV) then
    ''DELETE FILE FOR OVERWRITE
    objFSO.deletefile(strSAV)
  end if
  ''CREATE HTTP OBJECT
  set objHTTP = createobject("WinHttp.WinHttpRequest.5.1")
  ''DOWNLOAD FROM URL
  objHTTP.open "GET", strURL, false
  objHTTP.send
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
  if objFSO.fileexists(strSAV) then
    objOUT.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
    objLOG.write vbnewline & now & vbtab & vbtab & " - DOWNLOAD : " & strSAV & " : SUCCESSFUL"
  end if
	set objHTTP = nothing
  if ((err.number <> 0) and (err.number <> 58)) then        ''ERROR RETURNED DURING DOWNLOAD , 'ERRRET'=11
    call LOGERR(11)
  end if
end sub

sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  objOUT.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK" '& strCMD
  objLOG.write vbnewline & now & vbtab & vbtab & "EXECUTING : HOOK" '& strCMD
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
  set objHOOK = nothing
  if (err.number <> 0) then                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
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
  ''CUSTOM ERROR CODES
  select case intSTG
    case 1                                                  ''AUTO_PLANv2 - NOT ENOUGH ARGUMENTS, 'ERRRET'=1
    case 11                                                 ''AUTO_PLANv2 - CALL FILEDL() FAILED, 'ERRRET'=11
      objOUT.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 - CALL FILEDL() : " & strSAV
      objLOG.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 - CALL FILEDL() : " & strSAV
    case 12                                                 ''AUTO_PLANv2 - 'CALL HOOK() FAILED, 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
      objLOG.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 - CALL HOOK('STRCMD') : " & strCMD & " : FAILED"
  end select
end sub

sub CLEANUP()                                               ''SCRIPT CLEANUP
  on error resume next
  if (errRET = 0) then         												      ''AUTO_PLANv2 COMPLETED SUCCESSFULLY
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 SUCCESSFUL : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 SUCCESSFUL : " & now
    err.clear
  elseif (errRET <> 0) then    												      ''AUTO_PLANv2 FAILED
    objOUT.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 FAILURE : " & errRET & " : " & now
    objLOG.write vbnewline & vbnewline & now & vbtab & " - AUTO_PLANv2 FAILURE : " & errRET & " : " & now
    ''RAISE CUSTOMIZED ERROR CODE , ERROR CODE WILL BE DEFINED RESTOP NUMBER INDICATING WHICH SECTION FAILED
    call err.raise(vbObjectError + errRET, "AUTO_PLANv2", "fail")
  end if
  objOUT.write vbnewline & vbnewline & now & " - AUTO_PLANv2 COMPLETE. PLEASE VERIFY ALL MONITORING AND SERVICES!" & vbnewline
  objLOG.write vbnewline & vbnewline & now & " - AUTO_PLANv2 COMPLETE. PLEASE VERIFY ALL MONITORING AND SERVICES!" & vbnewline
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