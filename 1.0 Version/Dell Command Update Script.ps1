#This is to ensure that if an error happens, this script stops. 
$ErrorActionPreference = "Stop"

### Set your variables below this line ###
$DownloadURL = "https://wolftech.cc/6516510615/DCU.EXE"
$DownloadLocation = "C:\Temp"
$Reboot = "enable"
### Set your variables above this line ###

write-host "Download URL is set to $DownloadURL"
write-host "Download Location is set to $DownloadLocation"
 
#Check for 32bit or 64bit
$DCUExists32 = Test-Path "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
write-host "Does C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe exist? $DCUExists32"
$DCUExists64 = Test-Path "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
write-host "Does C:\Program Files\Dell\CommandUpdate\dcu-cli.exe exist? $DCUExists64"

if ($DCUExists32 -eq $true) {
    $DCUPath = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
}    
elseif ($DCUExists64 -eq $true) {
    $DCUPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
}

if (!$DCUExists32 -And !$DCUExists64) {
    
        $TestDownloadLocation = Test-Path $DownloadLocation
        write-host "$DownloadLocation exists? $($TestDownloadLocation)"
        
        if (!$TestDownloadLocation) { new-item $DownloadLocation -ItemType Directory -force 
            write-host "Temp Folder has been created"
        }
        
        $TestDownloadLocationZip = Test-Path "$($DownloadLocation)\DellCommandUpdate.exe"
        write-host "DellCommandUpdate.exe exists in $($DownloadLocation)? $($TestDownloadLocationZip)"
        
        if (!$TestDownloadLocationZip) { 
            write-host "Downloading DellCommandUpdate..."
            Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\DellCommandUpdate.exe"
            write-host "Installing DellCommandUpdate..."
            Start-Process -FilePath "$($DownloadLocation)\DellCommandUpdate.exe" -ArgumentList "/s" -Wait
            $DCUExists = Test-Path "$($DCUPath)"
            write-host "Done. Does $DCUPath exist now? $DCUExists"
            set-service -name 'DellClientManagementService' -StartupType Manual 
            write-host "Just set DellClientManagmentService to Manual"  
        }
}
    


$DCUExists = Test-Path "$DCUPath"
write-host "About to run $DCUPath. Lets be sure to be sure. Does it exist? $DCUExists"

Start-Process "$($DCUPath)" -ArgumentList "/scan -report=$($DownloadLocation)" -Wait
write-host "Checking for results."


$XMLExists = Test-Path "$DownloadLocation\DCUApplicableUpdates.xml"
if (!$XMLExists) {
        write-host "Something went wrong. Waiting 60 seconds then trying again..."
     Start-Sleep -s 60
    Start-Process "$($DCUPath)" -ArgumentList "/scan -report=$($DownloadLocation)" -Wait
    $XMLExists = Test-Path "$DownloadLocation\DCUApplicableUpdates.xml"
    write-host "Did the scan work this time? $XMLExists"
}
if ($XMLExists -eq $true) {
    [xml]$XMLReport = get-content "$DownloadLocation\DCUApplicableUpdates.xml"
    $AvailableUpdates = $XMLReport.updates.update
     
    $BIOSUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "BIOS" }).name.Count
    $ApplicationUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Application" }).name.Count
    $DriverUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Driver" }).name.Count
    $FirmwareUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Firmware" }).name.Count
    $OtherUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Other" }).name.Count
    $PatchUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Patch" }).name.Count
    $UtilityUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Utility" }).name.Count
    $UrgentUpdates = ($XMLReport.updates.update | Where-Object { $_.Urgency -eq "Urgent" }).name.Count
    
    #Print Results
    write-host "Bios Updates: $BIOSUpdates"
    write-host "Application Updates: $ApplicationUpdates"
    write-host "Driver Updates: $DriverUpdates"
    write-host "Firmware Updates: $FirmwareUpdates"
    write-host "Other Updates: $OtherUpdates"
    write-host "Patch Updates: $PatchUpdates"
    write-host "Utility Updates: $UtilityUpdates"
    write-host "Urgent Updates: $UrgentUpdates"
}

if (!$XMLExists) {
    write-host "We tried again and the scan still didn't run. Not sure what the problem is, but if you run the script again it'll probably work."
    exit 1
}
else {
    #We now remove the item, because we don't need it anymore, and sometimes fails to overwrite
    remove-item "$DownloadLocation\DCUApplicableUpdates.xml" -Force    
}
$Result = $BIOSUpdates + $ApplicationUpdates + $DriverUpdates + $FirmwareUpdates + $OtherUpdates + $PatchUpdates + $UtilityUpdates + $UrgentUpdates
write-host "Total Updates Available: $Result"
if ($Result -gt 0) {

    $OPLogExists = Test-Path "$DownloadLocation\updateOutput.log"
    if ($OPLogExists -eq $true) {
        remove-item "$DownloadLocation\updateOutput.log" -Force
    }

    write-host "Lets do it! Updating Drivers. This may take a while..."
    Start-Process "$($DCUPath)" -ArgumentList "/applyUpdates -autoSuspendBitLocker=enable -reboot=$($Reboot) -outputLog=$($DownloadLocation)\updateOutput.log" -Wait
    Start-Sleep -s 60
    Get-Content -Path '$DownloadLocation\updateOutput.log'
    write-host "Done."
    exit 0
}