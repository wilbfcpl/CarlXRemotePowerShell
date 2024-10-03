<# 
In it's current state, this is not a script that can be run straight through. I typically run these functions in PowerShell ISE using the run selection tool, making modifications when needed. Have future plans to make a CLI utility

This makes use of using Remote PowerShell to interact with resources, so that will need to be established.
You will need a csv file containing the host names of your pcs.

You will also need the newest version of CarlX.exe and a PowerShell script to activate it, which will be distributed out to be run locally.
#>


#Creates file pathing needed, if not already existing
# Change the location of your csv and local/remote file paths where applicable
Function Create-CarlFilePath {
	$Credentials = Get-Credential
	$RemoteComputer = Import-Csv "C:\Path\To\Your.csv" #change
	
	Invoke-Command  -Credential $Credentials -Computername $RemoteComputer.Name -ScriptBlock {
		If (!(Test-Path "C:\CarlUpgrade")){
			New-Item -Path "C:\CarlUpgrade" -ItemType Dir -Force
		}
	}
}



# Copy carlx.exe and powershell script from your local to remote machines
# Change the location of your csv and local/remote file paths where applicable
Function Copy-CarlFiles {
	$Credentials = Get-Credential
	$RemoteComputer = Import-Csv "C:\Path\To\Your.csv"
	
	$RemoteComputer | ForEach-Object {
		$Session = New-PSSession -ComputerName $_.Name 
		Copy-Item -Path "C:\CarlUpgrade\*" -Destination "C:\CarlUpgrade" -ToSession $Session -Credential $Credentials
	}
	Get-PSSession | Disconnect-PSSession
	Get-PSSession | Remove-PSSession
}



# Schedule a task to restart pc and then run carlx.exe
# Change the location of your csv, local/remote file paths, and desired upgrade time where applicable
Function Set-CarlUpgradeTime {
	$Credentials = Get-Credential
	$RemoteComputer = Import-Csv "C:\Path\To\Your.csv"

	Invoke-Command -Credential $Credentials -ComputerName $RemoteComputer.Name -ScriptBlock {

		# Schedule Restart
		$RestartTime = "01/01/2024 06:00"
		$RestartTaskName = "Restart-PC CarlX"       
		$RestartAction = New-ScheduledTaskAction -Execute Shutdown.exe "-r -f -t 0"    
		$RestartTrigger = New-ScheduledTaskTrigger -Once -At $RestartTime
		$RestartSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries
		$RestartTask = New-ScheduledTask -Action $RestartAction -Trigger $RestartTrigger -Settings $RestartSettings
		$RestartTaskUpdate = @{
			Trigger = $RestartTrigger
			Action = $RestartAction
			Settings = $RestartSettings
			User = "SYSTEM"
		}
		$RestartRegisterNewTask= @{
			TaskName = $RestartTaskName
			InputObject = $RestartTask
			User = "SYSTEM"
		}
		
		
		If (Get-ScheduledTask | Where-Object { $_.TaskName -eq "$RestartTaskName" }){
			Set-ScheduledTask $RestartTaskName @RestartTaskUpdate
		}
		Else {
			Register-ScheduledTask @RestartRegisterNewTask
		}
		
		###############################################################################################################

		# Schedule Upgrade
		$CarlUpgradeTime = "01/01/2024 06:30"
		$CarlInstallerPath = "C:\CarlUpgrade\UpgradeCarl.ps1" 
		$CarlTaskName = "Upgrade CarlX"       
		$CarlAction = New-ScheduledTaskAction -Execute PowerShell.exe "-ExecutionPolicy Bypass -File $CarlInstallerPath"    
		$CarlTrigger = New-ScheduledTaskTrigger -Once -At $CarlUpgradeTime
		$CarlSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries
		$CarlTask = New-ScheduledTask -Action $CarlAction -Trigger $CarlTrigger -Settings $CarlSettings
		$CarlTaskUpdate = @{
			Trigger = $CarlTrigger
			Action = $CarlAction
			Settings = $CarlSettings
			User = "SYSTEM"
		}
		$CarlRegisterNewTask= @{
			TaskName = $CarlTaskName
			InputObject = $CarlTask
			User = "SYSTEM"
		}
		
		
		If (Get-ScheduledTask | Where-Object { $_.TaskName -eq "$CarlTaskName" }){
			Set-ScheduledTask $CarlTaskName @CarlTaskUpdate
		}
		Else {
			Register-ScheduledTask @CarlRegisterNewTask
		}
	}
}



# Checks the version of staff.exe and exports results to a file
# Change the csv file and pathing as needed
Function Check-CarlVersion {
	# Import the list of hostnames from input.csv
	# Change this line to match csv
	$hostnames = Import-Csv -Path "C:\Path\To\Your.csv" | Select-Object -ExpandProperty Name

	# Initialize an empty array to store the results
	$results = @()

	# Loop through each hostname and query for program existence
	foreach ($hostname in $hostnames) {
		try {
			# Use Test-Connection to check if the hostname is reachable
			$pingResult = Test-Connection -ComputerName $hostname -Count 1 -ErrorAction Stop
			
			# If the host is reachable, attempt to check if the program exists
			if ($pingResult.StatusCode -eq 0) {
				$programPath = "\\$hostname\C$\Program Files\CarlX\Live\Staff.exe"
				$programExists = Test-Path -Path $programPath

				if ($programExists) {
					# If the program exists, add the result to the results array
					$results += [PSCustomObject]@{
						Name = $hostname
						Version = (Get-Item "\\$Hostname\C$\Program Files\CarlX\Live\Staff.exe").VersionInfo.FileVersion
					}
				} else {
					# If the program doesn't exist, add a result indicating that
					$results += [PSCustomObject]@{
						Name = $hostname
						Version = "Program Not Found"
					}
				}
			} else {
				# If the host is not reachable, add a result indicating that
				$results += [PSCustomObject]@{
					Name = $hostname
					Version = "Host Unreachable"
				}
			}
		} catch {
			# Handle any errors that may occur during the process
			$results += [PSCustomObject]@{
				Name = $hostname
				Version = "Error: $($_.Exception.Message)"
			}
		}
	}

	# Export the results to a CSV file
	#Change this line to match desired output file
	$results | Export-Csv -Path "C:\CarlUpgrade\Results.csv" -NoTypeInformation -Append
}
