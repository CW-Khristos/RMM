$MXB_path = "C:\ProgramData\MXB\"
$APIcredfile = join-path -Path $MXB_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
Remove-Item -Path $APIcredfile -Force