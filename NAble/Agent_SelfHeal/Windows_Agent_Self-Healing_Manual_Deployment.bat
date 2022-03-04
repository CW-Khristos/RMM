@ECHO OFF
REM ============================================
REM WINDOWS AGENT SELF-HEALING MANUAL DEPLOYMENT
REM ============================================
REM.
IF NOT EXIST C:\IT MD C:\IT
IF NOT EXIST C:\IT\Scripts MD C:\IT\Scripts
IF NOT EXIST C:\IT\Scripts\Tasks MD C:\IT\Scripts\Tasks
CURL -k --ssl-no-revoke "https://raw.githubusercontent.com/CW-Khristos/scripts/master/Agent_SelfHeal/AgentSelfHeal.ps1" -o "C:\IT\Scripts\AgentSelfHeal.ps1"
timeout 5
CURL -k --ssl-no-revoke "https://raw.githubusercontent.com/CW-Khristos/scripts/dev/Agent_SelfHeal/N-able_Windows_Agent_Self-Healing.xml" -o "C:\IT\Scripts\Tasks\N-able_Windows_Agent_Self-Healing.xml"
timeout 5
SchTasks /CREATE /TN "IPM Computers\N-able Windows Agent Self-Healing" /XML "C:\IT\Scripts\Tasks\N-able_Windows_Agent_Self-Healing.xml" /F
PowerShell -ExecutionPolicy Bypass -File C:\IT\Scripts\AgentSelfHeal.ps1
