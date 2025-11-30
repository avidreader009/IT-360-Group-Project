# IT-360-Group-Project

## Overview
The issue we solved with our tool is inefficient forensic data gathering. Our tool is a Windows PowerShell script that gathers system-level information (hardware information​, running processes​, I/O devices​, and system logs​) and outputs it to a text file which is then encrypted.

## List of Features
Encryption (AES-256) & Decryption Modes

Gathers the following information:
  - Computer Information (OS details, Bios details, Timezone)
  - Running Processes and Version
  - I/O Devices
  - System Log

## How to Setup and Run Tool
Our tool is intended for Windows devices. Ensure that you have an app that can run ps1 files. Download the **getInfo.ps1** file within the **src** folder. Run the **getInfo.ps1** file using the application of your choosing. The output file will appear in the same directory that the file is run from.

Apps we've tested our script with: Windows Terminal, Windows PowerShell ISE (ran as administrator), Windows Powershell
