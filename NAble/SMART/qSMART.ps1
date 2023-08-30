#REGION ----- DECLARATIONS ----
  #BELOW PARAM() MUST BE COMMENTED OUT FOR USE WITHIN NABLE NCENTRAL RMM
  #Param (
  #  [Parameter(Mandatory=$true)]$i_drive
  #)
  #SET DRIVE INDEX
  $script:i = -1
  $script:arrDRV = @()
  $script:selecteddrive = ""
  #SET TLS SECURITY FOR CONNECTING TO GITHUB
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#ENDREGION ----- DECLARATIONS ----

#REGION ----- FUNCTIONS ----
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
    write-output -ForegroundColor green $script:arrDRV[$script:i].drvID "     " $varID "     " $varVAL
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
#ENDREGION ----- FUNCTIONS ----

#------------
#BEGIN SCRIPT
$smartEXE = "C:\IT\smartctl.73.exe"
$dbEXE = "C:\IT\update-smart-drivedb.exe"
$srcSMART = "https://github.com/CW-Khristos/scripts/raw/master/SMART/smartctl.73.exe"
$srcDB = "https://github.com/CW-Khristos/scripts/raw/master/SMART/update-smart-drivedb.exe"
#CHECK 'PERSISTENT' FOLDERS
if (-not (test-path -path "C:\temp")) {
  new-item -path "C:\temp" -itemtype directory
}
if (-not (test-path -path "C:\IT")) {
  new-item -path "C:\IT" -itemtype directory
}
if (-not (test-path -path "C:\IT\Scripts")) {
  new-item -path "C:\IT\Scripts" -itemtype directory
}
write-output -ForegroundColor red " - UPDATING SMARTCTL"
#CLEANUP OLD VERSIONS OF 'SMARTCTL.EXE'
get-childitem -path "C:\IT"  | where-object {$_.name -match "smartctl"} | % {
  if ($_.name.split(".").length -le 2){
    write-output "     DELETE : " $_.name
    remove-item $_.fullname
  } elseif ($_.name.split(".").length -ge 3){
    if ($_.name.split(".")[1] -lt $smartEXE.split(".")[1]){
      write-output "     DELETE : " $_.name
      remove-item $_.fullname
    } else {
      write-output "     KEEP : " $_.name
    }
  }
}
#DOWNLOAD SMARTCTL.EXE IF NEEDED
if (-not (test-path -path $smartEXE -pathtype leaf)) {
  try {
    start-bitstransfer -erroraction stop -source $srcSMART -destination $smartEXE
  } catch {
    $web = new-object system.net.webclient
    $web.downloadfile($srcSMART, $smartEXE)
  }
}
#DOWNLOAD UPDATE-SMART-DRIVEDB.EXE IF NEEDED
if (-not (test-path -path $dbEXE -pathtype leaf)) {
  try {
    start-bitstransfer -erroraction stop -source $srcDB -destination $dbEXE
  } catch {
    $web = new-object system.net.webclient
    $web.downloadfile($srcDB, $dbEXE)
  }
}
#UPDATE SMARTCTL DRIVEDB.H
write-output -ForegroundColor red " - UPDATING SMARTCTL DRIVE DATABASE"
$output = Get-ProcessOutput -FileName $dbEXE -Args "/S"
#write-output -ForegroundColor green $output
#POPULATE DRIVES
write-output -ForegroundColor red " - ENUMERATING CONNECTED DRIVES"
$script:arrDRV = @()
#QUERY SMARTCTL FOR DRIVES
$output = Get-ProcessOutput -FileName $smartEXE -Args "--scan-open"
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
  if ($objDRV.drvID-eq $i_drive) {
    write-output -ForegroundColor red " - QUERYING DRIVE : $($objDRV.drvID)"
    $script:selecteddrive = $script:arrDRV | select-object * | where-object {$_.drvID -eq $objDRV.drvID}
    #GET BASIC SMART HEALTH
    $output = Get-ProcessOutput -FileName $smartEXE -Args "-H $($objDRV.drvID)"
    #PARSE SMARTCTL OUTPUT LINE BY LINE
    $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($line in $lines) {
      if ($line -ne $null) {
        if ($line -like "*SMART overall-health*") {
          #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
          $chunks = $line.split(":", [StringSplitOptions]::RemoveEmptyEntries)
          $script:arrDRV[$script:i].fail = $chunks[1].trim()
          write-output -ForegroundColor green $objDRV.drvID "     " $chunks[1].trim()
        }
      }
    }
    #GET SMART ATTRIBUTES
    $output = Get-ProcessOutput -FileName $smartEXE -Args "-A $($objDRV.drvID)"
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
                  #write-output -ForegroundColor green $chunks[0].trim() "     " $chunks1[0].trim()
                  mapSMART $chunks[0].trim() $chunks1[0].trim()
                } elseif ($line -notlike "*Celsius*") {                                               #"CELSIUS" NOT IN RAW VALUE
                  #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                  $chunks = $line.split(":", [StringSplitOptions]::RemoveEmptyEntries)
                  #write-output -ForegroundColor green $chunks[0].trim() "     " $chunks[($chunks.length - 1)].trim()
                  mapSMART $chunks[0].trim() $chunks[($chunks.length - 1)].replace("%", "").trim()
                }
              }
              default {
                if ($line -like "*(*)*") {                                                            #"()" IN RAW VALUE
                  #SPLIT 'LINE' OUTPUT INTO EACH RESPECTIVE SECTION
                  $chunks = $line.split("(", [StringSplitOptions]::RemoveEmptyEntries)
                  $chunks = $chunks[0].split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                  #write-output -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 1)].trim()
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
                      #write-output -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 7)].trim()
                      mapSMART $chunks[1].trim() $chunks[($chunks.length - 7)].trim()
                  #RETURN 'RAW' VALUES
                  } else {
                    #write-output -ForegroundColor green $chunks[1].trim() "     " $chunks[($chunks.length - 1)].trim()
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
      if ($prop.value -eq $null) {$prop.value = -1}
    }
    write-output " - SMART REPORT : " -ForegroundColor yellow
    $allout = "SMART REPORT DRIVE : $($script:arrDRV[$script:i].drvID)`r`n"
    #GET DRIVE IDENTITY
    $output = Get-ProcessOutput -FileName $smartEXE -Args "-i $($objDRV.drvID)"
    #PARSE SMARTCTL OUTPUT LINE BY LINE
    $lines = $output.StandardOutput.split("`r`n", [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($line in $lines) {
      $allout = "  - $($line)`r`n"
    }
    #BASIC HEALTH
    if ($script:arrDRV[$script:i].fail -eq "PASSED") {
      $ccode = "green"
    } else {
      $ccode = "red"
    }
    $allout += "  - SMART Health : $($script:arrDRV[$script:i].fail)`r`n"
    #HDD ATTRIBUTES
    $allout += "  - Reallocated Sectors (5) : $($script:arrDRV[$script:i].id5)`r`n"
    $allout += "  - Spin Retry Count (10) : $($script:arrDrv[$script:i].id10)`r`n"
    $allout += "  - End to End Error (184) : $($script:arrDRV[$script:i].id184)`r`n"
    $allout += "  - Uncorrectable Errors (187) : $($script:arrDRV[$script:i].id187)`r`n"
    $allout += "  - Command Timeout (188) : $($script:arrDRV[$script:i].id188)`r`n"
    $allout += "  - Airflow Temperature [C] (190) : $($script:arrDRV[$script:i].id190)`r`n"
    $allout += "  - Temperature [C] (194) : $($script:arrDRV[$script:i].id194)`r`n"
    $allout += "  - Reallocation Events (196) : $($script:arrDRV[$script:i].id196)`r`n"
    $allout += "  - Pending Sectors (197) : $($script:arrDRV[$script:i].id197)`r`n"
    $allout += "  - Offline Uncorrectable Sectors (198) : $($script:arrDRV[$script:i].id198)`r`n"
    $allout += "  - Soft Read Error Rate (201) : $($script:arrDRV[$script:i].id201)`r`n"
    #SSD ATTRIBUTES
    $allout += "  - Available Space (170) : $($script:arrDRV[$script:i].id170)`r`n"
    $allout += "  - Program Fail (171) : $($script:arrDRV[$script:i].id171)`r`n"
    $allout += "  - Erase Fail (172) : $($script:arrDRV[$script:i].id172)`r`n"
    $allout += "  - Wear Leveling (173) : $($script:arrDRV[$script:i].id173)`r`n"
    $allout += "  - Erase Fail (176) : $($script:arrDRV[$script:i].id176)`r`n"
    $allout += "  - Wear Leveling (177) : $($script:arrDRV[$script:i].id177)`r`n"
    $allout += "  - Program Fail (181) : $($script:arrDRV[$script:i].id181)`r`n"
    $allout += "  - Erase Fail (182) : $($script:arrDRV[$script:i].id182)`r`n"
    $allout += "  - Drive Life Protection (230) : $($script:arrDRV[$script:i].id230)`r`n"
    $allout += "  - SSD Life Left (231) : $($script:arrDRV[$script:i].id231)`r`n"
    $allout += "  - Endurance Remaining (232) : $($script:arrDRV[$script:i].id232)`r`n"
    #NVME ATRIBUTES
    $allout += "  - Critical Warning (NVMe) : $($script:arrDRV[$script:i].nvmewarn)`r`n"
    $allout += "  - Temperature [C] (NVMe) : $($script:arrDRV[$script:i].nvmetemp)`r`n"
    $allout += "  - Available Spare (NVMe) : $($script:arrDRV[$script:i].nvmeavail)`r`n"
    $allout += "  - Media / Data Integrity Errors (NVMe) : $($script:arrDRV[$script:i].nvmemdi)`r`n"
    $allout += "  - Error Info Log Entries (NVMe) : $($script:arrDRV[$script:i].nvmeerr)`r`n"
    $allout += "  - Warning Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmewctemp)`r`n"
    $allout += "  - Critical Comp. Temp Time (NVMe) : $($script:arrDRV[$script:i].nvmecctemp)"
    write-output $allout -foregroundcolor $ccode
    #NABLE RMM OUTPUT
    $o_fail = $script:arrDRV[$script:i].fail
    #HDD ATTRIBUTES
    $o_reallocated = $script:arrDRV[$script:i].id5
    $o_spinretry = $script:arrDrv[$script:i].id10
    $o_enderror = $script:arrDRV[$script:i].id184
    $o_uncorrectable = $script:arrDRV[$script:i].id187
    $o_command = $script:arrDRV[$script:i].id188
    $o_airtemp = $script:arrDRV[$script:i].id190
    $o_temperature = $script:arrDRV[$script:i].id194
    $o_reallocation = $script:arrDRV[$script:i].id196
    $o_pending = $script:arrDRV[$script:i].id197
    $o_offuncorrectable = $script:arrDRV[$script:i].id198
    $o_softread = $script:arrDRV[$script:i].id201
    #SSD ATTRIBUTES
    $o_availspace = $script:arrDRV[$script:i].id170
    $o_programfail = $script:arrDRV[$script:i].id171
    $o_erasefail = $script:arrDRV[$script:i].id172
    $o_wearlevel = $script:arrDRV[$script:i].id173
    $o_erasefail2 = $script:arrDRV[$script:i].id176
    $o_wearlevel2 = $script:arrDRV[$script:i].id177
    $o_programfail2 = $script:arrDRV[$script:i].id181
    $o_erasefail3 = $script:arrDRV[$script:i].id182
    $o_drivelife = $script:arrDRV[$script:i].id230
    $o_ssdlife = $script:arrDRV[$script:i].id231
    $o_endurance = $script:arrDRV[$script:i].id232
    #NVME ATRIBUTES
    $o_nvmewarn = $script:arrDRV[$script:i].nvmewarn
    $o_nvmetemp = $script:arrDRV[$script:i].nvmetemp
    $o_nvmeavail = $script:arrDRV[$script:i].nvmeavail
    $o_nvmemdi = $script:arrDRV[$script:i].nvmemdi
    $o_nvmeerr = $script:arrDRV[$script:i].nvmeerr
    $o_nvmewctemp = $script:arrDRV[$script:i].nvmewctemp
    $o_nvmecctemp = $script:arrDRV[$script:i].nvmecctemp
  }
}
#END SCRIPT
#------------