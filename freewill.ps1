# METHOD 1: Graceful form closure (Recommended)
# Replace the last part of your Destruct button click handler with:

$destructButton.Add_Click({
    # ... your existing destruct code ...
    
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
    
    # METHOD 1: Close the form gracefully
    $form.Close()
    $form.Dispose()
})

# ===================================

# METHOD 2: Add a timer for delayed closure
# Add this near the top of your script after creating the form:

$closeTimer = New-Object System.Windows.Forms.Timer
$closeTimer.Interval = 1000  # 1 second delay
$closeTimer.Add_Tick({
    $closeTimer.Stop()
    $form.Close()
    $form.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

# Then in your destruct button, replace the Stop-Process line with:
# $closeTimer.Start()

# ===================================

# METHOD 3: Complete replacement for the destruct button handler
$destructButton.Add_Click({
    # Disable the button to prevent multiple clicks
    $destructButton.Enabled = $false
    
    # Your existing destruct code here...
    $vdiskPath = "C:\temp\ddr.vhd"
    $diskNumber = $null
    $diskList = Get-Disk | Where-Object { $_.Location -like "*$vdiskPath*" }
    if ($diskList) {
        $diskNumber = $diskList.Number
    } else {
        Write-Host "Virtual disk not found or not attached. Aborting destruction."
        $form.Close()
        return
    }
    
    # Detach the virtual disk
    $detachScript = @"
select vdisk file="$vdiskPath"
detach vdisk
"@
    $detachFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $detachScript | Set-Content -Path $detachFile
    diskpart /s $detachFile | Out-Null
    Remove-Item -Path $detachFile -Force
    
    # Initialize the disk
    $initializeScript = @"
select disk $diskNumber
online disk
convert mbr
"@
    $initFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $initializeScript | Set-Content -Path $initFile
    diskpart /s $initFile | Out-Null
    Remove-Item -Path $initFile -Force
    
    # Create partition and assign drive letter
    $partitionScript = @"
select disk $diskNumber
create partition primary
assign letter=Z
"@
    $partFile = "C:\temp\$(Get-Random -Minimum 10000 -Maximum 99999).txt"
    $partitionScript | Set-Content -Path $partFile
    diskpart /s $partFile | Out-Null
    Remove-Item -Path $partFile -Force
    
    # Delete the virtual disk file
    if (Test-Path $vdiskPath) {
        Remove-Item -Path $vdiskPath -Force
    }
    
    # Clean up "Recent" shortcuts
    $recentPath = [Environment]::GetFolderPath("Recent")
    Get-ChildItem -Path $recentPath -Filter "*" | ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }
    
    # Destruct other stuff
    Remove-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\Z:" -ErrorAction SilentlyContinue
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\VolumeInfoCache\Z:" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Clear Temp
    Remove-Item -Path "C:\temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Stop-Process -Name vds -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "*.txt" | Where-Object { $_.Name -like "*PowerShell*" } | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Event logs
    Clear-EventLog -LogName System -ErrorAction SilentlyContinue
    wevtutil cl "Windows PowerShell" 2>$null
    
    # Remove Stuff from MuiCache
    Get-ItemProperty HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache -ErrorAction SilentlyContinue |
    ForEach-Object { $_.PSObject.Properties } |
    Where-Object { $_.Name -like "Z:\*" } |
    ForEach-Object { Remove-ItemProperty -Path "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -Name $_.Name -ErrorAction SilentlyContinue }
    
    # BAM
    Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State -ErrorAction SilentlyContinue | 
    ForEach-Object { $_.PSObject.Properties } | 
    Where-Object { $_.Name -match "mmc\.exe|diskpart\.exe" } | 
    ForEach-Object { Remove-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\Bam\State -Name $_.Name -ErrorAction SilentlyContinue }
    
    # Conhost History
    Set-Content "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" 'iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1   | iex' -ErrorAction SilentlyContinue
    
    # Clear JVM logs
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
    
    # Gracefully close the application
    $form.Close()
    $form.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
