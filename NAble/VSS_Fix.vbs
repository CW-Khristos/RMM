''VSS_FIX.VBS
''DESIGNED TO AUTOMATE RE-REGISTRATION OF VSS COMPONENTS
''WRITTEN BY : CJ BLEDSOE / CJ<@>THECOMPUTERWARRIORS.COM
''SCRIPT VARIABLES
dim strDIR
dim objOUT, objWSH, objHOOK
''CREATE OBJECTS
set objOUT = wscript.stdout
set objWSH = createobject("wscript.shell")
''SYSTEM DIRECTORY VARIABLE
strDIR = objWSH.ExpandEnvironmentStrings("%windir%")
strDIR = strDIR & "\system32\"
''STOP VSS SERVICES
objWSH.run "net stop " & chr(34) & "System Event Notification Service" & chr(34), 0, true
objWSH.run "net stop " & chr(34) & "Background Intelligent Transfer Service" & chr(34), 0, true
objWSH.run "net stop " & chr(34) & "COM+ Event System" & chr(34), 0, true
objWSH.run "net stop " & chr(34) & "Microsoft Software Shadow Copy Provider" & chr(34), 0, true
objWSH.run "net stop " & chr(34) & "Volume Shadow Copy" & chr(34), 0, true
''RE-REGISTER VSS COMPONENT FILES
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "ATL.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "comsvcs.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "credui.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "CRYPTNET.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "CRYPTUI.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "dhcpqec.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "dssenh.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "eapqec.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "es.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "esscli.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "FastProx.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "FirewallAPI.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "kmsvc.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "lsmproxy.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "MSCTF.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "msi.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "msxml.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "msxml3.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "msxml4.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "ncprov.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "ole32.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "oleaut32.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "stdprov.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "OLEACC.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "PROPSYS.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "QAgent.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "qagentrt.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "QUtil.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "raschap.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "RASQEC.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "rastls.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "repdrvfs.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "RPCRT4.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "rsaenh.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "SHELL32.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "shsvcs.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "vssvc" & chr(34) & " /register")
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s /i " & chr(34) & "swprv.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s /i " & chr(34) & "eventcls.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "tschannel.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "USERENV.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "vss_ps.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "vssui.dll" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wbemcons.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wbemcore.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wbemess.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wbemsvc.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "WINHTTP.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "WINTRUST.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wmiprvsd.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wmisvc.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wmiutils.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "regsvr32" & chr(34) & " /s " & chr(34) & "wuaueng.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "vssvc" & chr(34) & " /register")
''RUN SFC SCAN
call HOOK(chr(34) & strDIR & "sfc" & chr(34) & " /SCANFILE=" & chr(34) & strDIR & "catsrv.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "sfc" & chr(34) & " /SCANFILE=" & chr(34) & strDIR & "catsrvut.DLL" & chr(34))
call HOOK(chr(34) & strDIR & "sfc" & chr(34) & " /SCANFILE=" & chr(34) & strDIR & "CLBCatQ.DLL" & chr(34))
''RESTART VSS SERVICES
objWSH.run "net start " & chr(34) & "COM+ Event System" & chr(34), 0, true
objWSH.run "net start " & chr(34) & "Background Intelligent Transfer Service" & chr(34), 0, true
objWSH.run "net start " & chr(34) & "System Event Notification Service" & chr(34), 0, true
objWSH.run "net start " & chr(34) & "Microsoft Software Shadow Copy Provider" & chr(34), 0, true
objWSH.run "net start " & chr(34) & "Volume Shadow Copy" & chr(34), 0, true

sub HOOK(strCMD)                       ''CALL HOOK TO MONITOR OUTPUT OF CALLED COMMAND
  on error resume next
  'comspec = objWSH.ExpandEnvironmentStrings("%comspec%")
  set objHOOK = objWSH.exec(strCMD)
  while (not objHOOK.stdout.atendofstream)
    objOUT.write vbnewline & vbtab & (objHOOK.stdout.readline())
  wend
  wscript.sleep 10
  objOUT.write vbnewline & vbtab & objHOOK.stdout.readall()
  set objHOOK = nothing
  if (err.number <> 0) then
    objOUT.write vbnewline & vbtab & err.number & vbtab & err.description
  else
    objOUT.write vbnewline & vbtab & "SUCCESS"
  end if
end sub