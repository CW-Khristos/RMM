<#
.SYNOPSIS 
    Querys Drive SMART Attributes using SMARTCTL from https://www.smartmontools.org/

.DESCRIPTION
    Downloads 'smartctl.exe' utility from GitHub repo
    Querys Drive SMART Attributes using SMARTCTL from https://www.smartmontools.org/
 
.NOTES
    Version         : 0.1.0 (25 May 2023)
    Creation Date   : 25 May 2023
    Purpose/Change  : Querys Drive SMART Attributes using SMARTCTL
    File Name       : SMART_Statusv2.ps1 
    Author          : Christopher Bledsoe, Tier II Tech - IPM Computers
    Email           : cbledsoe@ipmcomputers.com
    Requires        : PowerShell Version 2.0+ installed

.CHANGELOG
    0.1.0 Initial Release

.TODO
    
#>
# Author : Christopher Bledsoe - cbledsoe@ipmcomputers.com

#region ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN DATTO RMM
  #UNCOMMENT BELOW PARAM() AND RENAME '$env:i_drive' TO '$i_drive' TO UTILIZE IN CLI
  #Param (
  #  [Parameter(Mandatory=$true)]$i_drive
  #)
  $script:i             = -1
  $script:diag          = $null
  $script:bitarch       = $null
  $script:blnWARN       = $false
  $script:blnBREAK      = $false
  $script:blnWARN       = $false
  $script:arrWARN       = [System.Collections.ArrayList]@()
  $script:arrDRV        = @()
  $script:selecteddrive = $null
  $exePath              = "$($env:strPath)"
  $smartEXE             = "smartctl.73.exe"
  $dbEXE                = "update-smart-drivedb.exe"
  $logPath              = "C:\IT\Log\SMART_Statusv2"
  $strLineSeparator     = "--------------------"
  $srcSMART             = "https://github.com/CW-Khristos/scripts/raw/master/SMART/smartctl.73.exe"
  $srcDB                = "https://github.com/CW-Khristos/scripts/raw/master/SMART/update-smart-drivedb.exe"
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#endregion ----- DECLARATIONS ----

#region ----- FUNCTIONS ----
  function write-DRMMDiag ($messages) {
    write-host "<-Start Diagnostic->"
    foreach ($message in $messages) {$message}
    write-host "<-End Diagnostic->"
  } ## write-DRMMDiag
  
  function write-DRMMAlert ($message) {
    write-host "<-Start Result->"
    write-host "Alert=$($message)"
    write-host "<-End Result->"
  } ## write-DRMMAlert

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

  function mapSMART($varID,$varVAL) {
    $varID = $varID.toupper().trim() -replace  "_", " "
    #write-host " - " $script:arrDRV[$script:i].drvID "     " $varID "     " $varVAL -ForegroundColor green
    #MAP SMART ATTRIBUTES BASED ON DRIVE TYPE
    switch ($script:arrDRV[$script:i].drvTYP) {
      #NVME DRIVES
      "nvme" {
        switch ($varID) {
          #---
          #---NVME ATTRIBUTES --- https://media.kingston.com/support/downloads/MKP_521.6_SMART-DCP1000_attribute.pdf
          #---
          "CRITICAL WARNING"
            {$script:arrDRV[$script:i].nvmewarn = [uint32]$varVAL}
          "TEMPERATURE"
            {$script:arrDRV[$script:i].nvmetemp = $varVAL}
          "AVAILABLE SPARE"
            {$script:arrDRV[$script:i].nvmeavail = $varVAL}
          "MEDIA AND DATA INTEGRITY ERRORS"
            {$script:arrDRV[$script:i].nvmemdi = $varVAL}
          "ERROR INFORMATION LOG ENTRIES"
            {$script:arrDRV[$script:i].nvmeerr = $varVAL}
          "WARNING  COMP. TEMPERATURE TIME"
            {$script:arrDRV[$script:i].nvmewctemp = $varVAL}
          "CRITICAL COMP. TEMPERATURE TIME"
            {$script:arrDRV[$script:i].nvmecctemp = $varVAL}
          default
            {}
        }
      }
      #HDD / SDD DRIVES
      default {
        switch ($varID) {
          #FOR MORE INFORMATION ABOUT SMART ATTRIBUTES : https://en.wikipedia.org/wiki/S.M.A.R.T.
          #---
          #---HDD ATTRIBUTES
          #---
          #SMART ID 1 Stores data related to the rate of hardware read errors that occurred when reading data from a disk surface
          #The raw value has different structure for different vendors and is often not meaningful as a decimal number
          #For some drives, this number may increase during normal operation without necessarily signifying errors
          "RAW READ ERROR RATE"
            {}
          #SMART ID 5 - CRITICAL -
          #Count of reallocated sectors
          #The raw value represents a count of the bad sectors that have been found and remapped
          #This value is primarily used as a metric of the life expectancy of the drive
          #A drive which has had any reallocations at all is significantly more likely to fail in the immediate months
          "REALLOCATED SECTOR CT"
            {$script:arrDRV[$script:i].id5 = $varVAL}
          #SMART ID 7 Rate of seek errors of the magnetic heads
          #If there is a partial failure in the mechanical positioning system, then seek errors will arise
          #Such a failure may be due to numerous factors, such as damage to a servo, or thermal widening of the hard disk
          #The raw value has different structure for different vendors and is often not meaningful as a decimal number
          #For some drives, this number may increase during normal operation without necessarily signifying errors
          "SEEK ERROR RATE"
            {}
          #SMART ID 9 Count of hours in power-on state
          #By default, the total expected lifetime of a hard disk in perfect condition is defined as 5 years (running every day and night on all days)
          #This is equal to 1825 days in 24/7 mode or 43800 hours
          "POWER ON HOURS"
            {}
          #SMART ID 10 - CRITICAL -
          #Count of retry of spin start attempts
          #This attribute stores a total count of the spin start attempts to reach the fully operational speed (under the condition that the first attempt was unsuccessful)
          #An increase of this attribute value is a sign of problems in the hard disk mechanical subsystem
          "SPIN RETRY COUNT"
            {$script:arrDRV[$script:i].id10 = $varVAL}
          #SMART ID 12 This attribute indicates the count of full hard disk power on/off cycles
          "POWER CYCLE COUNT"
            {}
          #SMART ID 184 - CRITICAL -
          #This attribute is a part of Hewlett-Packard's SMART IV technology, as well as part of other vendors' IO Error Detection and Correction schemas
          #Contains a count of parity errors which occur in the data path to the media via the drive's cache RAM
          {($_ -eq "END TO END ERROR") -or ($_ -eq "IOEDC") -or `
            ($_ -eq "END-TO-END ERROR") -or ($_ -eq "ERROR CORRECTION COUNT")}
              {$script:arrDRV[$script:i].id184 = $varVAL}
          #SMART ID 187 - CRITICAL -
          #The count of errors that could not be recovered using hardware ECC; see attribute 195
          {($_ -eq "REPORTED UNCORRECTABLE ERRORS") -or `
            ($_ -eq "UNCORRECTABLE ERROR CNT") -or ($_ -eq "REPORTED UNCORRECT")}
              {$script:arrDRV[$script:i].id187 = $varVAL}
          #SMART ID 188 - CRITICAL -
          #The count of aborted operations due to HDD timeout
          #Normally this attribute value should be equal to zero
          "COMMAND TIMEOUT"
            {$script:arrDRV[$script:i].id188 = $varVAL}
          #SMART ID 190 - CRITICAL -
          #Value is equal to (100-temp. °C), allowing manufacturer to set a minimum threshold which corresponds to a maximum temperature
          #This also follows the convention of 100 being a best-case value and lower values being undesirable
          #However, some older drives may instead report raw Temperature (identical to 0xC2) or Temperature minus 50 here.
          {($_ -eq "TEMPERATURE DIFFERENCE") -or `
            ($_ -eq "AIRFLOW TEMPERATURE") -or ($_ -eq "AIRFLOW TEMPERATURE CEL")}
              {$script:arrDRV[$script:i].id190 = $varVAL}
          #SMART ID 194 - CRITICAL -
          #Indicates the device temperature, if the appropriate sensor is fitted
          #Lowest byte of the raw value contains the exact temperature value (Celsius degrees)
          {($_ -eq "TEMPERATURE") -or ($_ -eq "TEMPERATURE CELSIUS")}
            {$script:arrDRV[$script:i].id194 = $varVAL}
          #SMART ID 196 -CRITICAL -
          #Count of remap operations
          #The raw value of this attribute shows the total count of attempts to transfer data from reallocated sectors to a spare area
          #Both successful and unsuccessful attempts are counted
          {($_ -eq "REALLOCATION EVENT COUNT") -or ($_ -eq "REALLOCATED EVENT COUNT")}
            {$script:arrDRV[$script:i].id196 = $varVAL}
          #SMART ID 197 - CRITICAL -
          #Count of "unstable" sectors (waiting to be remapped, because of unrecoverable read errors)
          #If an unstable sector is subsequently read successfully, the sector is remapped and this value is decreased
          #Read errors on a sector will not remap the sector immediately (since the correct value cannot be read and so the value to remap is not known, and also it might become readable later)
          #Instead, the drive firmware remembers that the sector needs to be remapped, and will remap it the next time it's written
          {($_ -eq "CURRENT PENDING SECTOR") -or ($_ -eq "CURRENT PENDING ECC CNT")}
            {$script:arrDRV[$script:i].id197 = $varVAL}
          #SMART ID 198 - CRITICAL -
          #The total count of uncorrectable errors when reading/writing a sector
          #A rise in the value of this attribute indicates defects of the disk surface and/or problems in the mechanical subsystem
          {($_ -eq "OFFLINE UNCORRECTABLE SECTOR COUNT") -or ($_ -eq "OFFLINE UNCORRECTABLE")}
            {$script:arrDRV[$script:i].id198 = $varVAL}
          #SMART ID 201 - CRITICAL -
          #Count indicates the number of uncorrectable software read errors
          {($_ -eq "SOFT READ ERROR RATE") -or ($_ -eq "TA COUNTER DETECTED")}
            {$script:arrDRV[$script:i].id201 = $varVAL}
          #---
          #---SSD ATTRIBUTES
          #---
          #SMART ID 5 - CRITICAL -
          "REALLOCATE NAND BLK CNT"
            #{$script:arrDRV[$script:i].ssd5 = $varVAL}
            {$script:arrDRV[$script:i].id5 = $varVAL}
          #SMART ID 170 - CRITICAL -
          #See attribute 232
          {($_ -eq "AVAILABLE SPACE") -or `
            ($_ -eq "UNUSED RSVD BLK CT CHIP") -or ($_ -eq "GROWN BAD BLOCKS")}
              {$script:arrDRV[$script:i].id170 = $varVAL}
              #{$script:arrDRV[$script:i].id180 = $varVAL}
              #{$script:arrDRV[$script:i].id202 = $varVAL}
              #{$script:arrDRV[$script:i].id231 = $varVAL}
              #{$script:arrDRV[$script:i].id232 = $varVAL}
          #SMART ID 171 - CRITICAL -
          #(Kingston) The total number of flash program operation failures since the drive was deployed
          #Identical to attribute 181
          {($_ -eq "PROGRAM FAIL") -or `
            ($_ -eq "PROGRAM FAIL COUNT") -or ($_ -eq "PROGRAM FAIL COUNT CHIP")}
              {$script:arrDRV[$script:i].id171 = $varVAL}
              #{$script:arrDRV[$script:i].id175 = $varVAL}
              #{$script:arrDRV[$script:i].id181 = $varVAL}
          #SMART ID 172 - CRITICAL -
          #(Kingston) Counts the number of flash erase failures
          #This attribute returns the total number of Flash erase operation failures since the drive was deployed
          #This attribute is identical to attribute 182
          {($_ -eq "ERASE FAIL") -or ($_ -eq "ERASE FAIL COUNT") -or ($_ -eq "ERASE FAIL COUNT CHIP")}
            {$script:arrDRV[$script:i].id172 = $varVAL}
            #{$script:arrDRV[$script:i].id176 = $varVAL}
            #{$script:arrDRV[$script:i].id182 = $varVAL}
          #SMART ID 173 - CRITICAL -
          #Counts the maximum worst erase count on any block
          {($_ -eq "WEAR LEVELING") -or ($_ -eq "WEAR LEVELING COUNT") -or `
            ($_ -eq "AVE BLOCK-ERASE COUNT") -or ($_ -eq "AVERAGE PE CYCLES TLC")}
              {$script:arrDRV[$script:i].id173 = $varVAL}
              #{$script:arrDRV[$script:i].id177 = $varVAL}
          #SMART ID 175 - CRITICAL -
          {($_ -eq "PROGRAM FAIL") -or ($_ -eq "PROGRAM FAIL COUNT CHIP")}
            #{$script:arrDRV[$script:i].id171 = $varVAL}
            {$script:arrDRV[$script:i].id175 = $varVAL}
            #{$script:arrDRV[$script:i].id181 = $varVAL}
          #SMART ID 176 - CRITICAL -
          #SMART parameter indicates a number of flash erase command failures
          {($_ -eq "ERASE FAIL") -or ($_ -eq "ERASE FAIL COUNT CHIP")}
            #{$script:arrDRV[$script:i].id172 = $varVAL}
            {$script:arrDRV[$script:i].id176 = $varVAL}
            #{$script:arrDRV[$script:i].id182 = $varVAL}
          #SMART ID 177 - CRITICAL -
          #Delta between most-worn and least-worn Flash blocks
          #It describes how good/bad the wear-leveling of the SSD works on a more technical way
          {($_ -eq "WEAR LEVELING COUNT") -or ($_ -eq "WEAR RANGE DELTA")}
            #{$script:arrDRV[$script:i].id173 = $varVAL}
            {$script:arrDRV[$script:i].id177 = $varVAL}
          #SMART ID 178 "Pre-Fail" attribute used at least in Samsung devices
          {($_ -eq "USED RESERVED BLOCK COUNT") -or ($_ -eq "USED RSVD BLK CNT CHIP")}
            {}
          #SMART ID 179 "Pre-Fail" attribute used at least in Samsung devices
          {($_ -eq "USED RESERVED") -or ($_ -eq "USED RSVD BLK CNT TOT")}
            {}
          #SMART ID 180 "Pre-Fail" attribute used at least in HP devices
          {($_ -eq "UNUSED RESERVED BLOCK COUNT TOTAL") -or `
            ($_ -eq "UNUSED RSVD BLK CNT TOT") -or ($_ -eq "UNUSED RESERVE NAND BLK")}
              #{$script:arrDRV[$script:i].id170 = $varVAL}
              {$script:arrDRV[$script:i].id180 = $varVAL}
              #{$script:arrDRV[$script:i].id202 = $varVAL}
              #{$script:arrDRV[$script:i].id231 = $varVAL}
              #{$script:arrDRV[$script:i].id232 = $varVAL}
          #SMART ID 181 - CRITICAL -
          #Total number of Flash program operation failures since the drive was deployed
          {($_ -eq "PROGRAM FAIL COUNT") -or ($_ -eq "PROGRAM FAIL CNT TOTAL")}
            #{$script:arrDRV[$script:i].id171 = $varVAL}
            #{$script:arrDRV[$script:i].id175 = $varVAL}
            {$script:arrDRV[$script:i].id181 = $varVAL}
          #SMART ID 182 - CRITICAL -
          #"Pre-Fail" Attribute used at least in Samsung devices
          {($_ -eq "ERASE FAIL COUNT") -or ($_ -eq "ERASE FAIL COUNT TOTAL")}
            #{$script:arrDRV[$script:i].id172 = $varVAL}
            #{$script:arrDRV[$script:i].id176 = $varVAL}
            {$script:arrDRV[$script:i].id182 = $varVAL}
          #SMART ID 183 the total number of data blocks with detected, uncorrectable errors encountered during normal operation
          #Although degradation of this parameter can be an indicator of drive aging and/or potential electromechanical problems, it does not directly indicate imminent drive failure
          "RUNTIME BAD BLOCK"
            {}
          #SMART ID 195 The raw value has different structure for different vendors and is often not meaningful as a decimal number
          #For some drives, this number may increase during normal operation without necessarily signifying errors.
          {($_ -eq "ECC ERROR RATE") -or ($_ -eq "HARDWARE ECC RECOVERED")}
            {}
          #SMART ID 199 The count of errors in data transfer via the interface cable as determined by ICRC (Interface Cyclic Redundancy Check)
          "CRC ERROR COUNT"
            {}
          #SMART ID 230 - CRITICAL -
          #Amplitude of "thrashing" (repetitive head moving motions between operations)
          #In SSDs, indicates whether usage trajectory is outpacing the expected life curve
          {($_ -eq "GMR HEAD AMPLITUDE") -or ($_ -eq "DRIVE LIFE PROTECTION")}
            {$script:arrDRV[$script:i].id230 = $varVAL}
          #SMART ID 202-PERCENT LIFE REMAIN & 231-SSD LIFE LEFT - CRITICAL -
          #Indicates the approximate SSD life left, in terms of program/erase cycles or available reserved blocks
          #A normalized value of 100 represents a new drive, with a threshold value at 10 indicating a need for replacement
          #A value of 0 may mean that the drive is operating in read-only mode to allow data recovery
          #Previously (pre-2010) occasionally used for Drive Temperature (more typically reported at 0xC2)
          {($_ -eq "SSD LIFE LEFT") -or ($_ -eq "PERCENT LIFETIME REMAIN") -or `
            ($_ -eq "MEDIA WEAROUT") -or ($_ -eq "MEDIA WEAROUT INDICATOR")}
              #{$script:arrDRV[$script:i].id170 = $varVAL}
              #{$script:arrDRV[$script:i].id180 = $varVAL}
              #{$script:arrDRV[$script:i].id202 = $varVAL}
              {$script:arrDRV[$script:i].id231 = $varVAL}
              #{$script:arrDRV[$script:i].id232 = $varVAL}
          #SMART ID 232 - CRITICAL -
          #Number of physical erase cycles completed on the SSD as a percentage of the maximum physical erase cycles the drive is designed to endure
          #Intel SSDs report the available reserved space as a percentage of the initial reserved space
          {($_ -eq "ENDURANCE REMAINING") -or ($_ -eq "AVAILABLE RESERVD SPACE")}
            #{$script:arrDRV[$script:i].id170 = $varVAL}
            #{$script:arrDRV[$script:i].id180 = $varVAL}
            #{$script:arrDRV[$script:i].id202 = $varVAL}
            #{$script:arrDRV[$script:i].id231 = $varVAL}
            {$script:arrDRV[$script:i].id232 = $varVAL}
          #SMART ID 233 Intel SSDs report a normalized value from 100, a new drive, to a minimum of 1
          #It decreases while the NAND erase cycles increase from 0 to the maximum-rated cycles
          #Previously (pre-2010) occasionally used for Power-On Hours (more typically reported in attribute 0x09)
          {($_ -eq "MEDIA WEAROUT") -or ($_ -eq "MEDIA WEAROUT INDICATOR")}
            {}
          #SMART ID 234 Decoded as: byte 0-1-2 = average erase count (big endian) and byte 3-4-5 = max erase count (big endian)
          {($_ -eq "AVERAGE ERASE COUNT") -or ($_ -eq "MAX ERASE COUNT") -or `
            ($_ -eq "AVERAGE ERASE COUNT AND MAXIMUM ERASE COUNT") -or ($_ -eq "AVG / MAX ERASE")}
              {}
          #SMART ID 235 Decoded as: byte 0-1-2 = good block count (big endian) and byte 3-4 = system (free) block count
          {($_ -eq "POR RECOVERY COUNT") -or ($_ -eq "GOOD BLOCK COUNT") -or ($_ -eq "SYSTEM FREE COUNT") -or `
            ($_ -eq "GOOD BLOCK COUNT AND SYSTEM FREE BLOCK COUNT") -or ($_ -eq "GOOD BLOCK / SYSTEM FREE COUNT")}
              {}
          #SMART ID 241 Total count of LBAs written
          "TOTAL LBAS WRITTEN"
            {}
          #UNKNOWNS
          {($_ -like "*UNKNOWN*")}
            {}
          default
            {}
        }
      }
    }
  } ## mapSMART SMART ATTRIBUTE MAPPING
  
  function chkSMART ($objDRV) {
    #BASIC HEALTH
    if (($objDRV.fail -ne "N/A") -and ($objDRV.fail -ne "PASSED")) {$script:blnWARN = $true; $script:arrWARN.add("  - SMART Health : $($script:arrDRV[$script:i].fail)`r`n")}
    #HDD ATTRIBUTES
    if (($objDRV.id5 -ne "N/A") -and ([int]$objDRV.id5 -gt 100)) {$script:blnWARN = $true; $script:arrWARN.add("  - Reallocated Sectors (5) : $($script:arrDRV[$script:i].id5)`r`n")}
    if (($objDRV.id10 -ne "N/A") -and ([int]$objDRV.id10 -gt 20)) {$script:blnWARN = $true; $script:arrWARN.add("  - Spin Retry Count (10) : $($script:arrDRV[$script:i].id10)`r`n")}
    if (($objDRV.id184 -ne "N/A") -and ([int]$objDRV.id184 -gt 0)) {$script:blnWARN = $true; $script:arrWARN.add("  - End to End Error (184) : $($script:arrDRV[$script:i].id184)`r`n")}
    if (($objDRV.id187 -ne "N/A") -and ([int]$objDRV.id187 -gt 5)) {$script:blnWARN = $true; $script:arrWARN.add("  - Uncorrectable Errors (187) : $($script:arrDRV[$script:i].id187)`r`n")}
    if (($objDRV.id188 -ne "N/A") -and ([int]$objDRV.id188 -gt 0)) {$script:blnWARN = $true; $script:arrWARN.add("  - Command Timeout (188) : $($script:arrDRV[$script:i].id188)`r`n")}
    if (($objDRV.id194 -ne "N/A") -and ([int]$objDRV.id194 -gt 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Temperature [C] (194) : $($script:arrDRV[$script:i].id194)`r`n")}
    if (($objDRV.id196 -ne "N/A") -and ([int]$objDRV.id196 -gt 200)) {$script:blnWARN = $true; $script:arrWARN.add("  - Reallocation Events (196) : $($script:arrDRV[$script:i].id196)`r`n")}
    if (($objDRV.id197 -ne "N/A") -and ([int]$objDRV.id197 -gt 100)) {$script:blnWARN = $true; $script:arrWARN.add("  - Pending Sectors (197) : $($script:arrDRV[$script:i].id197)`r`n")}
    if (($objDRV.id198 -ne "N/A") -and ([int]$objDRV.id198 -gt 0)) {$script:blnWARN = $true; $script:arrWARN.add("  - Offline Uncorrectable Sectors (198) : $($script:arrDRV[$script:i].id198)`r`n")}
    if (($objDRV.id201 -ne "N/A") -and ([int]$objDRV.id201 -gt 100)) {$script:blnWARN = $true; $script:arrWARN.add("  - Soft Read Error Rate (201) : $($script:arrDRV[$script:i].id201)`r`n")}
    #SSD ATTRIBUTES
    if (($objDRV.id170 -ne "N/A") -and ([int]$objDRV.id170 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Available Space (170) : $($script:arrDRV[$script:i].id170)`r`n")}
    if (($objDRV.id171 -ne "N/A") -and ([int]$objDRV.id171 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Program Fail (171) : $($script:arrDRV[$script:i].id171)`r`n")}
    if (($objDRV.id172 -ne "N/A") -and ([int]$objDRV.id172 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Erase Fail (172) : $($script:arrDRV[$script:i].id172)`r`n")}
    if (($objDRV.id173 -ne "N/A") -and ([int]$objDRV.id173 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Wear Leveling (173) : $($script:arrDRV[$script:i].id173)`r`n")}
    if (($objDRV.id176 -ne "N/A") -and ([int]$objDRV.id176 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Erase Fail (176) : $($script:arrDRV[$script:i].id176)`r`n")}
    if (($objDRV.id177 -ne "N/A") -and ([int]$objDRV.id177 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Wear Leveling (177) : $($script:arrDRV[$script:i].id177)`r`n")}
    if (($objDRV.id181 -ne "N/A") -and ([int]$objDRV.id181 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Program Fail (181) : $($script:arrDRV[$script:i].id181)`r`n")}
    if (($objDRV.id182 -ne "N/A") -and ([int]$objDRV.id182 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Erase Fail (182) : $($script:arrDRV[$script:i].id182)`r`n")}
    if (($objDRV.id190 -ne "N/A") -and ([int]$objDRV.id190 -gt 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Airflow Temperature [C] (190) : $($script:arrDRV[$script:i].id190)`r`n")}
    if (($objDRV.id230 -ne "N/A") -and ([int]$objDRV.id230 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Drive Life Protection (230) : $($script:arrDRV[$script:i].id230)`r`n")}
    if (($objDRV.id231 -ne "N/A") -and ([int]$objDRV.id231 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - SSD Life Left (231) : $($script:arrDRV[$script:i].id231)`r`n")}
    if (($objDRV.id232 -ne "N/A") -and ([int]$objDRV.id232 -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Endurance Remaining (232) : $($script:arrDRV[$script:i].id232)`r`n")} 
    #NVME ATTRIBUTES
    if (($objDRV.nvmewarn -ne "N/A") -and ([int]$objDRV.nvmewarn -gt 0)) {$script:blnWARN = $true; $script:arrWARN.add("  - Critical Warning (NVMe) : $($script:arrDRV[$script:i].nvmewarn)`r`n")}
    if (($objDRV.nvmetemp -ne "N/A") -and ([int]$objDRV.nvmetemp -gt 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Temperature [C] (NVMe) : $($script:arrDRV[$script:i].nvmetemp)`r`n")}
    if (($objDRV.nvmeavail -ne "N/A") -and ([int]$objDRV.nvmeavail -le 50)) {$script:blnWARN = $true; $script:arrWARN.add("  - Available Spare (NVMe) : $($script:arrDRV[$script:i].nvmeavail)`r`n")}
    if (($objDRV.nvmemdi -ne "N/A") -and ([int]$objDRV.nvmemdi -gt 0)) {$script:blnWARN = $true; $script:arrWARN.add("  - Media / Data Integrity Errors (NVMe) : $($script:arrDRV[$script:i].nvmemdi)`r`n")}
    #if (($objDRV.nvmeerr -ne "N/A") -and ([int]$objDRV.nvmeerr -gt 100)) {$script:blnWARN = $true; $script:arrWARN.add("  - Error Info Log Entries (NVMe) : $($script:arrDRV[$script:i].nvmeerr)`r`n")}
    if (($objDRV.nvmewctemp -ne "N/A") -and ([int]$objDRV.nvmewctemp -gt 5)) {$script:blnWARN = $true; $script:arrWARN.add("  - Warning Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmewctemp)`r`n")}
    if (($objDRV.nvmecctemp -ne "N/A") -and ([int]$objDRV.nvmecctemp -gt 5)) {$script:blnWARN = $true; $script:arrWARN.add("  - Critical Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmecctemp)`r`n")}
  } ## chkSMART

  function StopClock {
    #Stop script execution time calculation
    $script:sw.Stop()
    $Days = $sw.Elapsed.Days
    $Hours = $sw.Elapsed.Hours
    $Minutes = $sw.Elapsed.Minutes
    $Seconds = $sw.Elapsed.Seconds
    $Milliseconds = $sw.Elapsed.Milliseconds
    $ScriptStopTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
    write-host "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds"
    $script:diag += "`r`nTotal Execution Time - $($Minutes) Minutes : $($Seconds) Seconds : $($Milliseconds) Milliseconds`r`n"
  }

  function logERR ($intSTG, $strModule, $strErr) {
    $script:blnWARN = $true
    #CUSTOM ERROR CODES
    switch ($intSTG) {
      1 {                                                         #'ERRRET'=1 - NOT ENOUGH ARGUMENTS, END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - NO ARGUMENTS PASSED, END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - NO ARGUMENTS PASSED, END SCRIPT`r`n" -foregroundcolor red
      }
      2 {                                                         #'ERRRET'=2 - END SCRIPT
        $script:blnBREAK = $true
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - ($($strModule)) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - ($($strModule)) :" -foregroundcolor red
        write-host "$($strLineSeparator)`r`n`t$($strErr), END SCRIPT`r`n`r`n" -foregroundcolor red
      }
      3 {                                                         #'ERRRET'=3
        $script:blnWARN = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor yellow
      }
      default {                                                   #'ERRRET'=4+
        $script:blnBREAK = $false
        $script:diag += "`r`n$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - $($strModule) :"
        $script:diag += "`r`n$($strLineSeparator)`r`n`t$($strErr)"
        write-host "$($strLineSeparator)`r`n$($(get-date)) - SMART_Statusv2 - $($strModule) :" -foregroundcolor yellow
        write-host "$($strLineSeparator)`r`n`t$($strErr)" -foregroundcolor red
      }
    }
  }

  function dir-Check () {
  #CHECK 'PERSISTENT' FOLDERS
    if (-not (test-path -path "C:\temp")) {
      new-item -path "C:\temp" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT")) {
      new-item -path "C:\IT" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Log")) {
      new-item -path "C:\IT\Log" -itemtype directory -force
    }
    if (-not (test-path -path "C:\IT\Scripts")) {
      new-item -path "C:\IT\Scripts" -itemtype directory -force
    }
    if (-not (test-path -path "$($exePath)")) {
      new-item -path "$($exePath)" -itemtype directory -force | out-string
    }
  }

  function run-Deploy () {
    #CHECK 'PERSISTENT' FOLDERS
    dir-Check
    #CHECK IF SMARTCTL IS RUNNING
    $varAttempts = 0
    $running = get-process "$($smartEXE)" -erroraction silentlycontinue
    while (($running) -and ($varAttempts -lt 3)) {
      $varAttempts++
      $result = taskkill /IM "$($smartEXE)" /F
      start-sleep -seconds 5
      $result = get-process "$($smartEXE)" -erroraction silentlycontinue
      if ($result) {                   #SMARTCTL STILL RUNNING
        $running = $true
      } elseif (-not $result) {        #SMARTCTL NO LONGER RUNNING
        $running = $false
      }
    }
    if (-not $running) {
      try {
        if (test-path -path "$($exePath)\$($dbEXE)") {remove-item "$($exePath)\$($dbEXE)" -force -erroraction continue}
        if (test-path -path "$($exePath)\$($smartEXE)") {remove-item "$($exePath)\$($smartEXE)" -force -erroraction continue}
        #DOWNLOAD SMARTCTL FROM GITHUB
        if (-not (test-path -path "$($exePath)\$($smartEXE)")) {
          try {
            $depdiag = " - BITS.Transfer - Downloading : $($srcSMART) : $($exePath)\$($smartEXE)"
            logERR 3 "run-Deploy" "$($depdiag)"
            start-bitstransfer -erroraction stop -source "$($srcSMART)" -destination "$($exePath)\$($smartEXE)"
            $depdiag = " - SMARTCTL Downloaded Successfully`r`n$($strLineSeparator)"
            logERR 3 "run-Deploy" "$($depdiag)"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
            $depdiag = " - BITS.Transfer - FAILED TO DOWNLOAD SMARTCTL`r`n$($err)"
            logERR 3 "run-Deploy" "$($depdiag)"
            try {
              $depdiag = " - Web.DownloadFile - Downloading : $($srcSMART) : $($exePath)\$($smartEXE)`r`n$($strLineSeparator)"
              logERR 3 "run-Deploy" "$($depdiag)"
              $web = new-object system.net.webclient
              $web.downloadfile("$($srcSMART)", "$($exePath)\$($smartEXE)")
              $depdiag = " - SMARTCTL Downloaded Successfully`r`n$($strLineSeparator)"
              logERR 3 "run-Deploy" "$($depdiag)"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
              $depdiag = " - Web.DownloadFile - FAILED TO DOWNLOAD SMARTCTL`r`n$($err)"
              logERR 2 "run-Deploy" "$($depdiag)"
            }
          }
        }
        #DOWNLOAD UPDATE-SMART-DRIVEDB.EXE FROM GITHUB
        if (-not (test-path -path "$($exePath)\$($dbEXE)")) {
          try {
            $depdiag = " - BITS.Transfer - Downloading : $($srcDB) : $($exePath)\$($dbEXE)"
            logERR 3 "run-Deploy" "$($depdiag)"
            start-bitstransfer -erroraction stop -source "$($srcDB)" -destination "$($exePath)\$($dbEXE)"
            $depdiag = " - UPDATE-SMART-DRIVEDB Downloaded Successfully`r`n$($strLineSeparator)"
            logERR 3 "run-Deploy" "$($depdiag)"
          } catch {
            $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
            $depdiag = " - BITS.Transfer - FAILED TO DOWNLOAD UPDATE-SMART-DRIVEDB`r`n$($err)"
            logERR 3 "run-Deploy" "$($depdiag)"
            try {
              $depdiag = " - Web.DownloadFile - Downloading : $($srcDB) : $($exePath)\$($dbEXE)`r`n$($strLineSeparator)"
              logERR 3 "run-Deploy" "$($depdiag)"
              $web = new-object system.net.webclient
              $web.downloadfile("$($srcDB)", "$($exePath)\$($dbEXE)")
              $depdiag = " - UPDATE-SMART-DRIVEDB Downloaded Successfully`r`n$($strLineSeparator)"
              logERR 3 "run-Deploy" "$($depdiag)"
            } catch {
              $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
              $depdiag = " - Web.DownloadFile - FAILED TO DOWNLOAD UPDATE-SMART-DRIVEDB`r`n$($err)"
              logERR 2 "run-Deploy" "$($depdiag)"
            }
          }
        }
        # inform the user
        if (-not $script:blnBREAK) {
          $depdiag = " - DEPLOY SMARTCTL COMPLETED - smartctl has been deployed`r`n"
          $depdiag += "`t - SMARTCTL Location : '$($exePath)\$($smartEXE)'`r`n$($strLineSeparator)"
          logERR 3 "run-Deploy" "$($depdiag)"
        } elseif ($script:blnBREAK) {
          $depdiag = " - DEPLOY SMARTCTL FAILED - smartctl has not been deployed`r`n$($strLineSeparator)"
          logERR 2 "run-Deploy" "$($depdiag)"
        }
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $depdiag = " - DEPLOY SMARTCTL FAILED - smartctl has not been deployed`r`n$($err)"
        logERR 2 "run-Deploy" "$($depdiag)"
      }
    }
  }

  function run-Monitor () {
    #CHECK PATH EXISTENCE
    $result = test-path -path "$($exePath)"
    if (-not $result) {                   #PATH DOES NOT EXIST, DEPLOY SMARTCTL
      run-Deploy
    } elseif ($result) {                  #PATH EXISTS
      #CHECK EXECUTABLE AND DLL
      $exeFile = test-path -path "$($exePath)\$($smartEXE)"
      $dbFile = test-path -path "$($exePath)\$($dbEXE)"
      if ((-not $exeFile) -or (-not $dbFile)) {
        run-Deploy
      }
      try {
        $mondiag = " - UPDATING SMARTCTL`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($mondiag)"
        #CLEANUP OLD VERSIONS OF 'SMARTCTL.EXE'
        get-childitem -path "$($exePath)"  | where-object {$_.name -match "smartctl"} | % {
          if ($_.name.split(".").length -le 2){
            $mondiag = " - DELETE : $($_.name)`r`n$($strLineSeparator)"
            logERR 3 "run-Monitor" "$($mondiag)"
            remove-item $_.fullname
          } elseif ($_.name.split(".").length -ge 3){
            if ($_.name.split(".")[1] -lt $smartEXE.split(".")[1]) {
              $mondiag = " - DELETE : $($_.name)`r`n$($strLineSeparator)"
              logERR 3 "run-Monitor" "$($mondiag)"
              remove-item $_.fullname
            } else {
              $mondiag = " - KEEP : $($_.name)`r`n$($strLineSeparator)"
              logERR 3 "run-Monitor" "$($mondiag)"
            }
          }
        }
        #DOWNLOAD SMARTCTL.EXE IF NEEDED
        if (-not (test-path -path "$($exePath)\$($smartEXE)" -pathtype leaf)) {
          try {
            start-bitstransfer -erroraction stop -source "$($srcSMART)" -destination "$($exePath)\$($smartEXE)"
          } catch {
            $web = new-object system.net.webclient
            $web.downloadfile("$($srcSMART)", "$($exePath)\$($smartEXE)")
          }
        }
        #DOWNLOAD UPDATE-SMART-DRIVEDB.EXE IF NEEDED
        if (-not (test-path -path "$($exePath)\$($dbEXE)" -pathtype leaf)) {
          try {
            start-bitstransfer -erroraction stop -source "$($srcDB)" -destination "$($exePath)\$($dbEXE)"
          } catch {
            $web = new-object system.net.webclient
            $web.downloadfile("$($srcDB)", "$($exePath)\$($dbEXE)")
          }
        }
        #UPDATE SMARTCTL DRIVEDB.H
        $mondiag = " - UPDATING SMARTCTL DRIVE DATABASE`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($mondiag)"
        $output = Get-ProcessOutput -FileName "$($exePath)\$($dbEXE)" -Args "/S"
        #logERR 3 "run-Monitor" "$($output)"

        #QUERY SMARTCTL FOR DRIVES
        $mondiag = " - ENUMERATING CONNECTED DRIVES`r`n$($strLineSeparator)"
        logERR 3 "run-Monitor" "$($mondiag)"
        $output = Get-ProcessOutput -FileName "$($exePath)\$($smartEXE)" -Args "--scan-open"
        #PARSE SMARTCTL OUTPUT LINE BY LINE
        $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
        foreach ($line in $lines) {
          if ($line -ne $null) {
            #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
            $chunks = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
            #POPULATE INITIAL DRIVE HASHTABLE
            $script:arrDRV += New-Object -TypeName PSObject -Property @{
              #DRIVE ID, TYPE, HEALTH DETAILS
              drvID = $chunks[0].trim()
              drvTYP = $chunks[2].trim()
              fail = $null
              #HDD ATTRIBUTES
              id5 = $null
              id10 = $null
              id184 = $null
              id187 = $null
              id188 = $null
              id190 = $null
              id194 = $null
              id196 = $null
              id197 = $null
              id198 = $null
              id201 = $null
              #SSD ATTRIBUTES
              id170 = $null
              id171 = $null
              id172 = $null
              id173 = $null
              id175 = $null
              id176 = $null
              id177 = $null
              id180 = $null
              id181 = $null
              id182 = $null
              id230 = $null
              id231 = $null
              id232 = $null
              #NVME ATTRIBUTES
              nvmewarn = $null
              nvmetemp = $null
              nvmeavail = $null
              nvmemdi = $null
              nvmeerr = $null
              nvmewctemp = $null
              nvmecctemp = $null
            }
          }
        }
        #ENUMERATE EACH DRIVE
        foreach ($objDRV in $arrDRV) {
          $script:i = ($script:i + 1)
          if ($objDRV.drvID -eq $i_drive) {
            $mondiag = " - QUERYING DRIVE : $($objDRV.drvID)`r`n$($strLineSeparator)"
            logERR 3 "run-Monitor" "$($mondiag)"
            $script:selecteddrive = $script:arrDRV | select-object * | where-object {$_.drvID -eq $objDRV.drvID}
            #GET BASIC SMART HEALTH
            $output = Get-ProcessOutput -FileName "$($exePath)\$($smartEXE)" -Args "-H $($objDRV.drvID)"
            #PARSE SMARTCTL OUTPUT LINE BY LINE
            $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
            foreach ($line in $lines) {
              if ($line -ne $null) {
                if ($line -like "*SMART overall-health*") {
                  #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                  $chunks = $line.split(":", [StringSplitOptions]::RemoveEmptyEntries)
                  $script:arrDRV[$script:i].fail = $chunks[1].trim()
                  #write-host -ForegroundColor green $objDRV.drvID "     " $chunks[1].trim()
                }
              }
            }
            #GET SMART ATTRIBUTES
            $output = Get-ProcessOutput -FileName "$($exePath)\$($smartEXE)" -Args "-A $($objDRV.drvID)"
            #PARSE SMARTCTL OUTPUT LINE BY LINE
            $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
            foreach ($line in $lines) {
              if ($line -ne $null) {
                if (($line -notlike "*: Unknown *") -and ($line -notlike "*Please specify*") -and ($line -notlike "*Use smartctl*") -and `
                  ($line -notlike "*smartctl*") -and ($line -notlike "*Copyright (C)*") -and ($line -notlike "*=== START*") -and `
                  ($line -notlike "*SMART Attributes Data*") -and ($line -notlike "*Vendor Specific SMART*") -and `
                  ($line -notlike "*ID#*") -and ($line -notlike "*SMART/Health Information*")) {
                    #MAP SMART ATTRIBUTES BASED ON DRIVE TYPE
                    switch ($script:arrDRV[$script:i].drvTYP) {
                      "nvme" {
                        if ($line -like "*Celsius*") {                                                        #"CELSIUS" IN RAW VALUE
                          #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                          $chunks = $line.split(":", [StringSplitOptions]::RemoveEmptyEntries)
                          $chunks1 = $chunks[($chunks.length -1)].split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                          #write-host -ForegroundColor green $chunks[0].trim() "     " $chunks1[0].trim()
                          mapSMART $chunks[0].trim() $chunks1[0].trim()
                        } elseif ($line -notlike "*Celsius*") {                                               #"CELSIUS" NOT IN RAW VALUE
                          #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                          $chunks = $line.split(":", [StringSplitOptions]::RemoveEmptyEntries)
                          #write-host -ForegroundColor green $chunks[0].trim() "     " $chunks[($chunks.length - 1)].trim()
                          mapSMART $chunks[0].trim() $chunks[($chunks.length - 1)].replace("%", "").trim()
                        }
                      }
                      default {
                        if ($line -like "*(*)*") {                                                            #"()" IN RAW VALUE
                          #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                          $chunks = $line.split("(", [StringSplitOptions]::RemoveEmptyEntries)
                          $chunks = $chunks[0].split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                          #write-host -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 1)].trim()
                          mapSMART $chunks[1].trim() $chunks[($chunks.length - 1)].trim()
                        } elseif ($line -notlike "*(*)*") {                                                   #"()" NOT IN RAW VALUE
                          #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                          $chunks = $line.split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                          #RETURN 'NORMALIZED' VALUES
                          if (($line -like "*Grown_Bad_Blocks*") -or `
                            ($line -like "*Ave_Block-Erase_Count*") -or ($line -like "*Average_PE_Cycles_TLC*") -or `
                            ($line -like "*Program_Fail*") -or ($line -like "*Erase_Fail*") -or `
                            ($line -like "*Wear_Leveling*") -or ($line -like "*Percent_Lifetime_Remain*") -or `
                            ($line -like "*Used_Rsvd_Blk*") -or ($line -like "*Used_Reserved*") -or `
                            ($line -like "*Unused_Rsvd_Blk*") -or ($line -like "*Unused_Reserved*") -or `
                            ($line -like "*Available_Reservd_Space*") -or ($line -like "*Media_Wearout*")) {
                              #write-host -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 7)].trim()
                              mapSMART $chunks[1].trim() $chunks[($chunks.length - 7)].trim()
                          #RETURN 'RAW' VALUES
                          } else {
                            #write-host -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 1)].trim()
                            mapSMART $chunks[1].trim() $chunks[($chunks.length - 1)].trim()
                          }
                        }
                      }
                    }
                }
              }
            }
            #OUTPUT
            foreach ($prop in $script:arrDRV[$script:i].psobject.properties) {
              if ($prop.value -eq $null) {$prop.value = "N/A"}
            }
            #CHECK SMART ATTRIBUTE VALUES
            chkSMART $script:arrDRV[$script:i]
            $mondiag = " - SMART REPORT :`r`n$($strLineSeparator)"
            logERR 3 "run-Monitor" "$($mondiag)"
            $allout = " - SMART REPORT DRIVE : $($script:arrDRV[$script:i].drvID)`r`n"
            if ($script:arrWARN.count -eq 0) {
              $allout += "`t  - All SMART Attributes passed checks`r`n"
            } elseif ($script:arrWARN.count -gt 0) {
              $allout += "`t  - The following SMART Attributes did not pass :`r`n"
              foreach ($warn in $script:arrWARN) {$allout += "`t`t$($warn)"}
            }
            #GET DRIVE IDENTITY
            $output = Get-ProcessOutput -FileName "$($exePath)\$($smartEXE)" -Args "-i $($objDRV.drvID)"
            #PARSE SMARTCTL OUTPUT LINE BY LINE
            $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
            foreach ($line in $lines) {$allout += "`t  - $($line)`r`n"}
            $allout += "`t  - SMART Health : $($script:arrDRV[$script:i].fail)`r`n"
            #HDD ATTRIBUTES
            $allout += "`t  - Reallocated Sectors (5) : $($script:arrDRV[$script:i].id5)`r`n"
            $allout += "`t  - Spin Retry Count (10) : $($script:arrDRV[$script:i].id10)`r`n"
            $allout += "`t  - End to End Error (184) : $($script:arrDRV[$script:i].id184)`r`n"
            $allout += "`t  - Uncorrectable Errors (187) : $($script:arrDRV[$script:i].id187)`r`n"
            $allout += "`t  - Command Timeout (188) : $($script:arrDRV[$script:i].id188)`r`n"
            $allout += "`t  - Airflow Temperature [C] (190) : $($script:arrDRV[$script:i].id190)`r`n"
            $allout += "`t  - Temperature [C] (194) : $($script:arrDRV[$script:i].id194)`r`n"
            $allout += "`t  - Reallocation Events (196) : $($script:arrDRV[$script:i].id196)`r`n"
            $allout += "`t  - Pending Sectors (197) : $($script:arrDRV[$script:i].id197)`r`n"
            $allout += "`t  - Offline Uncorrectable Sectors (198) : $($script:arrDRV[$script:i].id198)`r`n"
            $allout += "`t  - Soft Read Error Rate (201) : $($script:arrDRV[$script:i].id201)`r`n"
            #SSD ATTRIBUTES
            $allout += "`t  - Available Space (170) : $($script:arrDRV[$script:i].id170)`r`n"
            $allout += "`t  - Program Fail (171) : $($script:arrDRV[$script:i].id171)`r`n"
            $allout += "`t  - Erase Fail (172) : $($script:arrDRV[$script:i].id172)`r`n"
            $allout += "`t  - Wear Leveling (173) : $($script:arrDRV[$script:i].id173)`r`n"
            $allout += "`t  - Erase Fail (176) : $($script:arrDRV[$script:i].id176)`r`n"
            $allout += "`t  - Wear Leveling (177) : $($script:arrDRV[$script:i].id177)`r`n"
            $allout += "`t  - Program Fail (181) : $($script:arrDRV[$script:i].id181)`r`n"
            $allout += "`t  - Erase Fail (182) : $($script:arrDRV[$script:i].id182)`r`n"
            $allout += "`t  - Drive Life Protection (230) : $($script:arrDRV[$script:i].id230)`r`n"
            $allout += "`t  - SSD Life Left (231) : $($script:arrDRV[$script:i].id231)`r`n"
            $allout += "`t  - Endurance Remaining (232) : $($script:arrDRV[$script:i].id232)`r`n"
            #NVME ATRIBUTES
            $allout += "`t  - Critical Warning (NVMe) : $($script:arrDRV[$script:i].nvmewarn)`r`n"
            $allout += "`t  - Temperature [C] (NVMe) : $($script:arrDRV[$script:i].nvmetemp)`r`n"
            $allout += "`t  - Available Spare (NVMe) : $($script:arrDRV[$script:i].nvmeavail)`r`n"
            $allout += "`t  - Media / Data Integrity Errors (NVMe) : $($script:arrDRV[$script:i].nvmemdi)`r`n"
            $allout += "`t  - Error Info Log Entries (NVMe) : $($script:arrDRV[$script:i].nvmeerr)`r`n"
            $allout += "`t  - Warning Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmewctemp)`r`n"
            $allout += "`t  - Critical Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmecctemp)`r`n"
            logERR 3 "run-Monitor" "$($allout)`r`n$($strLineSeparator)"
          }
        }
      } catch {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $mondiag = "MONITOR SMARTCTL FAILED :`r`n$($err)"
        logERR 2 "run-Monitor" "$($mondiag)"
      }
    }
  }

  function run-Upgrade () {
    try {
      run-Remove
    } catch {
      
    }
    try {
      run-Deploy
    } catch {
      
    }
  }

  function run-Remove () {
    #CHECK IF SMARTCTL IS RUNNING
    $varAttempts = 0
    $running = get-process "$($smartEXE)" -erroraction silentlycontinue
    while (($running) -and ($varAttempts -lt 3)) {
      $varAttempts++
      $result = taskkill /IM "$($smartEXE)" /F
      start-sleep -seconds 5
      $result = get-process "$($smartEXE)" -erroraction silentlycontinue
      if ($result) {                   #SMARTCTL STILL RUNNING
        $running = $true
      } elseif (-not $result) {        #SMARTCTL NO LONGER RUNNING
        $running = $false
      }
    }
    #REMOVE FILES
    try {
      $remdiag = " - Removing smartctl Files`r`n$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
      remove-item -path "$($exePath)" -recurse -force -erroraction continue
      $remdiag = " - smartctl Files Removed`r`n$($strLineSeparator)"
      logERR 3 "run-Remove" "$($remdiag)"
    } catch {
      if ($_.exception -match "ItemNotFoundException") {
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $remdiag = " - NOT PRESENT : $($_.fullname)`r`n$($err)"
        logERR 2 "run-Remove" "$($remdiag)"
      } elseif ($_.exception -notmatch "ItemNotFoundException") {
        $script:blnWARN = $true
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $remdiag = " - REMOVE SMARTCTL FAILED :`r`n$($err)"
        logERR 2 "run-Remove" "$($remdiag)"
      } else {
        $script:blnWARN = $true
        $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
        $remdiag = " - REMOVE SMARTCTL FAILED :`r`n$($err)"
        logERR 2 "run-Remove" "$($remdiag)"
      }
    }
  }
#endregion ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
clear-host
#Start script execution time calculation
$ScrptStartTime = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
$script:sw = [Diagnostics.Stopwatch]::StartNew()
#CHECK 'PERSISTENT' FOLDERS
dir-Check

if ($env:strTask -eq "DEPLOY") {
  logERR 3 "run-Deploy" " - Deploying smartctl Files`r`n$($strLineSeparator)"
  try {
    run-Deploy -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "run-Deploy" " - Deploying smartctl Files`r`n$($err)"
  }
} elseif ($env:strTask -eq "MONITOR") {
  logERR 3 "run-Deploy" " - Monitoring smartctl Files`r`n$($strLineSeparator)"
  try {
    run-Monitor -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "run-Monitor" " - Monitoring smartctl Files`r`n$($err)"
  }
} elseif ($env:strTask -eq "UPGRADE") {
  logERR 3 "run-Upgrade" " - Replacing smartctl Files`r`n$($strLineSeparator)"
  try {
    run-Upgrade -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "run-Upgrade" " - Replacing smartctl Files`r`n$($err)"
  }
} elseif ($env:strTask -eq "REMOVE") {
  logERR 3 "run-Remove" " - Removing smartctl Files`r`n$($strLineSeparator)"
  try {
    run-Remove -erroraction stop
    
  } catch {
    $err = "$($_.Exception)`r`n$($_.scriptstacktrace)`r`n$($_)`r`n$($strLineSeparator)"
    logERR 2 "run-Remove" " - Removing smartctl Files Failed :`r`n$($err)"
  }
}
#DATTO OUTPUT
#Stop script execution time calculation
StopClock
#CLEAR LOGFILE
$null | set-content $logPath -force
$finish = (get-date -format "yyyy-MM-dd HH:mm:ss").ToString()
if (-not $script:blnBREAK) {
  if ($env:strTask -eq "DEPLOY") {
    $alert = "SMARTCTL Files Deployed"
  } elseif ($env:strTask -eq "MONITOR") {
    $alert = "SMARTCTL - Healthy"
  } elseif ($env:strTask -eq "UPGRADE") {
    $alert = "SMARTCTL Files Replaced"
  } elseif ($env:strTask -eq "REMOVE") {
    $alert = "SMARTCTL Files Removed"
  }
  if (-not $script:blnWARN) {
    $result = "$($env:strTask) : $($alert) : Execution Successful : $($finish)"
  } elseif ($script:blnWARN) {
    $result = "$($env:strTask) : $($alert) : Execution Completed with Warnings : $($finish)"
  }
  $enddiag += " - $($result)`r`n$($strLineSeparator)`r`n`t - $($alert)`r`n$($strLineSeparator)`r`n"
  logERR 3 "SMART_Statusv2" "$($enddiag)"
  #WRITE TO LOGFILE
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "SMART_Statusv2 : $($result)"
  write-DRMMDiag "$($script:diag)"
  exit 0
} elseif ($script:blnBREAK) {
  $result = "$($env:strTask) : Execution Failed : $($finish)"
  $enddiag = " - $($result)`r`n$($strLineSeparator)`r`n"
  logERR 4 "SMART_Statusv2" "$($enddiag)"
  #WRITE TO LOGFILE
  "$($script:diag)" | add-content $logPath -force
  write-DRMMAlert "SMART_Statusv2 : $($result) : Diagnostics - $($logPath)"
  write-DRMMDiag "$($script:diag)"
  exit 1
}
#END SCRIPT
#------------