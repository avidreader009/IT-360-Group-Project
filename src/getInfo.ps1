param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Encrypt","Decrypt")]
    [string]$Mode,

    [string]$InputFile,
    [string]$OutputFile
)

function Protect-FileAes {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$OutFile,
        [Parameter(Mandatory = $true)] [string]$Password
    )
    
    # create random 16 byte salt
    $salt = New-Object byte[] 16
    $rng  = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt)

    # uses PBKDF2 to derive AES key and IV from pw and salt
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000)

    # create AES256 encryptor
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 256
    $aes.Key     = $derive.GetBytes(32)
    $aes.IV      = $derive.GetBytes(16)

    $inStream      = [System.IO.File]::OpenRead($Path)
    $outStream     = New-Object System.IO.FileStream($OutFile, [System.IO.FileMode]::Create)
    $cryptoStream  = $null

    try {
        # write salt + IV
        $outStream.Write($salt, 0, 16)
        $outStream.Write($aes.IV, 0, 16)

        # create cryptostream that performs AES encryption
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream(
            $outStream,
            $aes.CreateEncryptor(),
            [System.Security.Cryptography.CryptoStreamMode]::Write
        )

        # copies encryption input file through encryption stream
        $inStream.CopyTo($cryptoStream)

        # finalize block cipher padding
        $cryptoStream.FlushFinalBlock()
    }
    finally {
        if ($cryptoStream) { $cryptoStream.Dispose() }
        $inStream.Dispose()
        $outStream.Dispose()
        $aes.Dispose()
        $rng.Dispose()
    }
}

function Decrypt-FileAes {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$OutFile,
        [Parameter(Mandatory = $true)] [string]$Password
    )

    # open encrypted file for reading
    $inStream     = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open)
    $outStream    = $null
    $cryptoStream = $null
    $aes          = $null

    try {
        # read salt + IV from start of file
        $salt = New-Object byte[] 16
        $iv   = New-Object byte[] 16

        if ($inStream.Read($salt, 0, 16) -ne 16) { throw "Invalid encrypted file (missing salt)." }
        if ($inStream.Read($iv,   0, 16) -ne 16) { throw "Invalid encrypted file (missing IV)." }

        # derive key/IV
        $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000)
        $aes    = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Key     = $derive.GetBytes(32)
        $aes.IV      = $iv

        $outStream = New-Object System.IO.FileStream($OutFile, [System.IO.FileMode]::Create)

        try {
            # create cryptostream in read mode
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream(
                $inStream,
                $aes.CreateDecryptor(),
                [System.Security.Cryptography.CryptoStreamMode]::Read
            )

            $cryptoStream.CopyTo($outStream)
        }
        catch [System.Security.Cryptography.CryptographicException] {
            # if password is wrong it deletes incomplete plaintext
            if ($outStream) { $outStream.Dispose() }
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
            throw "Incorrect password."
        }
    }
    finally {
        if ($cryptoStream) { $cryptoStream.Dispose() }
        if ($outStream)    { $outStream.Dispose() }
        if ($aes)          { $aes.Dispose() }
        $inStream.Dispose()
    }
}

if ($mode -eq "Encrypt") {
    
    if (-not $InputFile)  { $InputFile  = ".\Information.txt" }
    if (-not $OutputFile) { $OutputFile = ".\Information.enc" }

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
    Write-Output "Get commands have finished running. Encrypting output file..."

    $plainPath     = ".\Information.txt"
    $encryptedPath = ".\Information.enc"

    # Prompt for password (won't echo to screen)
    $securePassword = Read-Host "Enter encryption password" -AsSecureString

    # Convert SecureString -> plain text (only in memory, briefly) for key derivation
    $BSTR          = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    # Encrypt file with AES
    Protect-FileAes -Path $plainPath -OutFile $encryptedPath -Password $plainPassword

    # Optionally delete the plaintext file
    Remove-Item $plainPath

    Write-Output "Encryption complete. Encrypted file: $encryptedPath"
}

elseif ($Mode -eq "Decrypt") {

    # if no input/output paths are chosen, go to defualt 
    if (-not $InputFile)  { $InputFile  = ".\Information.enc" }
    if (-not $OutputFile) { $OutputFile = ".\Information_decrypted.txt" }

    Write-Host "[*] Decrypting file..."

    # prompts user for password
    $securePassword = Read-Host "Enter decryption password" -AsSecureString

    #converts securestring to plaintext
    $bstr           = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword  = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)

    #wipes the bstr so pw is not left in memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    try {
        
        # attempt to decrypt file
        Decrypt-FileAes -Path $InputFile -OutFile $OutputFile -Password $plainPassword
        Remove-Item $InputFile -Force
        Write-Host "[+] Decryption complete -> $OutputFile"
    }
    catch {

        # if any errors occur, displays the message
        Write-Host "[!] $_"
    }
}