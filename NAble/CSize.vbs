on error resume next

dim retSTOP
dim objOUT, objSIZ
dim objWSH, objFSO, objFOL

set objWSH = createobject("wscript.shell")
set objFSO = createobject("scripting.filesystemobject")
set objOUT = wscript.stdout

retSTOP = 0

if (objFSO.folderexists("C:\Users")) then
  call getSIZ("C:\Users")
elseif (objFSO.folderexists("C:\Documents and Settings")) then
  call getSIZ("C:\Documents and Settings")
end if
call CLEANUP

sub getSIZ(strFOL)
  set objSIZ = objWSH.exec("%comspec% /c dir /A /S " & chr(34) & strFOL & chr(34) & " > " & chr(34) & "C:\CSize.txt")
  'while (objSIZ.status = 0)
    while (not objSIZ.StdOut.atendofstream)
      objOUT.write vbnewline & (objSIZ.stdout.readline())
      wscript.sleep 10
    wend
  'wend
  objOUT.write vbnewline & objSIZ.stdout.readall()
  retSTOP = objSIZ.exitcode
  set objSIZ = nothing
end sub

sub CLEANUP()
  if (retSTOP <> 0) then
    Call Err.Raise(vbObjectError + retSTOP, "CSize", "fail")
  end if
  set objOUT = nothing
  set objFSO = nothing
  set objWSH = nothing
  wscript.quit err.number
end sub