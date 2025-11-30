# output hardware information header to file
"Hardware information: " | Out-File -FilePath .\Information.txt

# get hardware information
Get-ComputerInfo -Property "Windows*", "Bios*", "Os*", "TimeZone" | Out-File -FilePath .\Information.txt -Append

# output running processes header to file
"Running Processes: " | Out-File -FilePath .\Information.txt -Append

# get running processes and version
Get-Process | ForEach-Object {
    try {
        # checks if a path exists for each process. if so, version information is retrieved and added to the file
        if ($_.Path) {
            $versionInfo = (Get-Item $_.Path).VersionInfo
            Write-Output "$($_.Name) $($versionInfo.FileVersion)"
        }
        # if a path doesn't exist, the below text is added to the file
        else {
            Write-Output "$($_.Name) has no executable path. Version information cannot be obtained."
        }
    }
    catch {
        Write-Output "$($_.Name) had an error occur."
    }
} | Out-File -FilePath .\Information.txt -Append

# output io devices header to file
"I/O Devices: " | Out-File -FilePath .\Information.txt -Append

# get io devices
Get-PnpDevice | Out-File -FilePath .\Information.txt -Append

# output system logs header to file
"System Logs: " | Out-File -FilePath .\Information.txt -Append

# get system log
Get-EventLog -LogName System| Out-File -FilePath .\Information.txt -Append

#write output to host to inform user that commands have finished running
Write-Output "Get commands have finished running. Check Information.txt"
