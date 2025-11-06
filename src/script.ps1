#get hardware information
Get-ComputerInfo -Property "Windows*", "Bios*", "Os*", "TimeZone" | Export-csv -Path ".\Information.csv" -NoTypeInformation

#get running processes and version
Get-Process -FileVersionInfo | Export-Csv -Path ".\Information.csv" -NoTypeInformation -Append

#get io devices
Get-PnpDevice | Export-Csv -Path ".\Information.csv" -NoTypeInformation -Append

#get system logs
Get-EventLog | Export-Csv -Path ".\Information.csv" -NoTypeInformation -Append
