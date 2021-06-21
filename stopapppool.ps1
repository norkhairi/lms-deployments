$applicationPoolName = $args[0]
if ((Get-WebAppPoolState -Name $applicationPoolName).Value -ne 'Stopped'){
    Write-Host ('Stopping Application Pool')
	Write-Host $applicationPoolName
    Stop-WebAppPool -Name $applicationPoolName
} 