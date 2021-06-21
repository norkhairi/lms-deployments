$applicationPoolName = $args[0]
if((Get-WebAppPoolState -Name $applicationPoolName).Value -ne 'Started'){
    Write-Output ('Starting Application Pool')
	Write-Host $applicationPoolName
    Start-WebAppPool -Name $applicationPoolName
} 