# Close applications if they're running
Get-Process | Where-Object { ($_.Name -Eq "Staff") -Or ($_.Name -Eq "ITS International") -Or ($_.Name -Eq "Admin") } | Stop-Process -Force


# Start installer as a process and wait for it to finish
Start-Process -FilePath "$PSScriptRoot\CarlX.exe" -ArgumentList "/VerySilent" -ErrorAction "SilentlyContinue" -Wait