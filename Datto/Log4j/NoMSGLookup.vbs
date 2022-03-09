''NOMSGLOOKUP.VBS
''DESIGNED TO AUTOMATE LOG4J 'NOMSGLOOKUP' CONFIGURATIONS TO MITIGATE LOG4J RCE VULNERABILITY
''VULNERABLE LOG4J JAR FILES WILL STILL NEED TO BE REPLACED

''DOES NOT REQUIRE PARAMETERS
''WRITTEN BY : CJ BLEDSOE / CBLEDSOE<@>IPMCOMPUTERS.COM
on error resume next
''SCRIPT VARIABLES
dim strRCMD, intRET
''STDIN / STDOUT
set objIN = wscript.stdin
set objOUT = wscript.stdout
set objARG = wscript.arguments
''OBJECTS FOR LOCATING FOLDERS
set objWSH = createobject("wscript.shell")

''------------
''BEGIN SCRIPT
call HOOK("setx LOG4J_FORMAT_MSGMNO_LOOKUPS true")
wscript.sleep 2000
objOUT.write vbnewline & now & vbtab & " - Adding System ENV Variable : 'LOG4J_FORMAT_MSGMNO_LOOKUPS'"
set objENV = objWSH.Environment("System")
intRET = objENV("LOG4J_FORMAT_MSGMNO_LOOKUPS") = "true"
if (not intRET) then
  call LOGERR(intRET)
elseif (intRET) then
  objOUT.write vbnewline & now & vbtab & vbtab & "SUCCESS: Specified value was saved." 
end if
set objENV = nothing
wscript.sleep 2000
objOUT.write vbnewline & now & vbtab & " - Adding User ENV Variable : 'LOG4J_FORMAT_MSGMNO_LOOKUPS'"
set objENV = objWSH.Environment("User")
intRET = objENV("LOG4J_FORMAT_MSGMNO_LOOKUPS") = "true"
if (not intRET) then
  call LOGERR(intRET)
elseif (intRET) then
  objOUT.write vbnewline & now & vbtab & vbtab & "SUCCESS: Specified value was saved." 
end if
objOUT.write vbnewline & now & vbtab & " - Expanded ENV String : " & objWSH.expandenvironmentstrings("%LOG4J_FORMAT_MSGMNO_LOOKUPS%") & vbnewline
''END SCRIPT
set objENV = nothing
wscript.quit
''END SCRIPT
''------------

''SUB-ROUTINES
sub HOOK(strCMD)                                            ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND , 'ERRRET'=12
  on error resume next
  strRCMD = strCMD
  objOUT.write vbnewline & now & vbtab & " - EXECUTING : HOOK(" & strCMD & ")"
  set objHOOK = objWSH.exec(strCMD)
  if (instr(1, strCMD, "takeown /F ") = 0) then             ''SUPPRESS 'TAKEOWN' SUCCESS MESSAGES
    while (not objHOOK.stdout.atendofstream)
      strIN = objHOOK.stdout.readline
      if (strIN <> vbnullstring) then
        objOUT.write vbnewline & now & vbtab & vbtab & strIN 
      end if
    wend
    wscript.sleep 10
    strIN = objHOOK.stdout.readall
    if (strIN <> vbnullstring) then
      objOUT.write vbnewline & now & vbtab & vbtab & strIN
    end if
  end if
  set objHOOK = nothing
  if (err.number <> 0) then                                 ''ERROR RETURNED DURING UPDATE CHECK , 'ERRRET'=12
    call LOGERR(12)
  end if
  strRCMD = vbnullstring
end sub

sub LOGERR(intSTG)                                          ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  errRET = intSTG
  if (err.number <> 0) then
    objOUT.write vbnewline & now & vbtab & vbtab & err.number & vbtab & err.description & vbnewline
		err.clear
  end if
  select case intSTG
    case 12                                                 ''NOMSGLOOKUP - 'CALL HOOK() FAILED, 'ERRRET'=12
      objOUT.write vbnewline & vbnewline & now & vbtab & " - NOMSGLOOKUP - CALL HOOK('STRCMD') : " & strRCMD & " : FAILED"
  end select
end sub