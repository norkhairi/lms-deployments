# General deployment script
Param(
    [ValidateNotNullOrEmpty()]
    [string]$transitfolder = "E:\transit",
    [ValidateNotNullOrEmpty()]
    [string[]]$regions,
    [ValidateNotNullOrEmpty()]
    [string]$environment = "dev",
    [ValidateNotNullOrEmpty()]
    [string]$serversfile = "E:\Tools\Scripts\lms-servers.json",
    [ValidateNotNullOrEmpty()]
    [string]$test = "true"
)

# $transitfolder    e.g E:\transit
# $region           e.g 01.Americas
# $environment      e.g DEV or qa
# $serversfile      e.g E:\Tools\Scripts\lms-servers.json

Write-Host "`r`nDEPLOYMENT STARTED`r`n"

$data = Get-Content -Raw -Path $serversfile | ConvertFrom-Json

$servers = $data.remotes

# Array of solutions list that will be used for deployment
$solutions = @('Amway.Learning.Mobile.Admin.Website','Amway.Learning.Mobile.WebAPI','Amway.Learning.Mobile.Website','Amway.Learning.ILTInstructor.Website','Amway.Learning.Schedular')

foreach ($region in $regions) {

    $workspacepath = "$workspacefolder\$pipeline\Source\Amway.Learning.Mobile"
    $droppath = "$dropfolder\$pipeline\Release\_PublishedWebsites\$solution"
    $transitpath = "$transitfolder\$environment\Web\LMSMobile"

    if ($test -eq "true") {
        $remotewebfolder = "Web\LMSMobile\deploy-bak"
    }
    else {
        $remotewebfolder = "Web\LMSMobile"
    }

    foreach ($server in $servers)
    {
        if ($server.name -eq $region)
        {
            $regionID = $($server.name).substring(0,2)

            Write-Host "`r`n========================================================================================================================`r`n"
            Write-Host "`r`nMOVING FILES to Region $regionID ( $($server.name) ) $environment server`r`n"
            Write-Host "`r`n========================================================================================================================"

            foreach ($farm in $server.$environment)
            {

                foreach ($nodes in $farm)
                {
                    Write-Host "`r`nENV=$($environment), INSTANCE=$($region), FARM=$($nodes.farm), NODE=$($nodes.node), REMOTE=$($nodes.name)`r`n"

                    Write-Host "`r`n`r`nStep $region - 01 : PERMISSION TESTING`r`n"

                    # Start check for special case servers (e.g QA GCR)
                    if ($nodes.domain) {

                        # $nodes.domain
                        # $nodes.username
                        # $nodes.password

                        Write-Host "$($server.name) $environment remote server"

                        Start-Sleep -Seconds 2

                        Write-Host "`r`nStep $region - 01.1 : Attempting to unmount remote share \\$($nodes.name)\e$ drive if it's already mounted..."

                        net use \\$($nodes.name)\e$ /delete

                        Start-Sleep -Seconds 5

                        Write-Host "`r`nStep $region - 01.2 : Attempting to mount remote share \\$($nodes.name)\e$ drive`r`n"

                        net use \\$($nodes.name)\e$ /user:$($nodes.domain)\$($nodes.username) $($nodes.password)

                        if ($LASTEXITCODE -eq 0) {

                            Write-Host "Successfully mounted \\$($nodes.name)\e$"

                        } else {

                            Write-Error "Received non-zero error $($LASTEXITCODE). Exiting..." -ErrorAction Stop

                        }
                    }
                    # End check for special case servers

                    # START PERMISSION TESTING
                    Write-Host "`r`n`Test upload copy permissiontest.txt to remote \\$($nodes.name)\e$\ storage`r`n"

                    Copy-Item -Path "E:\Tools\Scripts\permissiontest.txt" -Destination "\\$($nodes.name)\e$\" -recurse

                    if(-not $?) {

                        Write-Error "`r`nCopy Failed`r`n" -ErrorAction Stop

                        exit 1

                    } else {

                        Write-Host "`r`nCopied Successfully`r`n"
                    }

                    Write-Host "`r`nDelete uploaded copy permissiontest.txt on remote \\$($nodes.name)\e$\ storage`r`n"

                    Remove-Item "\\$($nodes.name)\e$\permissiontest.txt"

                    if(-not $?) {

                        Write-Error "`r`nDelete Failed`r`n" -ErrorAction Stop

                        exit 1

                    } else {

                        Write-Host "`r`nSuccessfully deleted`r`n"

                    }
                    # END PERMISSION TESTING

                    Write-Host "`r`Delete existing zip files in remote server's web folder before uploading new zip file`r`n"

                    Remove-Item "\\$($nodes.name)\e$\$($remotewebfolder)\$region.zip" -Recurse -ErrorVariable capturedErrors -ErrorAction 'Ignore'

                    $capturedErrors | foreach-object { if ($_ -notmatch "does not exist") { write-error $_ } }

                    # Start copying zipped LMS files from transit folder to remote server's folder
                    Write-Host "`r`nStart copying zipped LMS files from transit folder to remote server's web folder`r`n"

                    $ValidRemotePath = Test-Path -Path "\\$($nodes.name)\e$\$($remotewebfolder)"

                    if ($ValidRemotePath -eq $False)
                    {
                        New-Item -Path "\\$($nodes.name)\e$\$($remotewebfolder)" -ItemType directory
                        try {
                            Copy-Item -Path "$transitpath\$region.zip" -Destination "\\$($nodes.name)\e$\$($remotewebfolder)\$region.zip" -Recurse -Force -ErrorAction 'Stop'
                        }
                        catch {
                            Write-Error "ERROR!! $_" -ErrorAction 'Stop'
                        }
                    }
                    else {
                        try {
                            Copy-Item -Path "$transitpath\$region.zip" -Destination "\\$($nodes.name)\e$\$($remotewebfolder)\$region.zip" -Recurse -Force -ErrorAction 'Stop'
                        }
                        catch {
                            Write-Error "ERROR!! $_" -ErrorAction 'Stop'
                        }
                    }

                    # Check if there are more than 2 backup folders, then delete the oldest one
                    $currentDate = (Get-Date -Format g)

                    if ((Get-ChildItem -Path "\\$($nodes.name)\e$\Web\LMSMobile" -Filter "$($region)-*" -Directory).Count -gt 3) {

                        Get-ChildItem -Path "\\$($nodes.name)\e$\Web\LMSMobile" -Filter "$($region)-*" -Directory | ForEach-Object {

                            if ($_.LastWriteTime -lt $currentDate) {

                                $currentDate = $_.LastWriteTime
                                $OldFolder = $_.FullName

                            }

                        }
                        Write-Host 'Deleting old backup web folder ' $OldFolder
                    }


                    # Write-Host "`r`nBacking up existing remote server's web folder in zip file before deploying new files`r`n"

                    # Compress-Archive -Path "\\$($nodes.name)\e$\Web\LMSMobile\$region" -DestinationPath "\\$($nodes.name)\e$\$region-$((Get-Date).ToString('yyyy_MM_dd-hh_mm_ss')).zip"

                    if ($test -eq "false") {
                        Write-Host "`r`nBacking up existing remote server's web folder before deploying new files by renaming it to \\$($nodes.name)\e$\Web\LMSMobile\$region-$((Get-Date).ToString('yyyy_MM_dd-hh_mm_ss'))-bak`r`n"

                        try {
                            Rename-Item "\\$($nodes.name)\e$\Web\LMSMobile\$region" "\\$($nodes.name)\e$\Web\LMSMobile\$region-$((Get-Date).ToString('yyyy_MM_dd-hh_mm_ss'))-bak"
                        }
                        catch {
                            Write-Error "ERROR!! $_" -ErrorAction 'Stop'
                        }
                    }

                    Write-Host "`r`Delete existing remote server web folder before deploying new files`r`n"

                    try {
                        Remove-Item "\\$($nodes.name)\e$\$($remotewebfolder)\$region" -Recurse -ErrorVariable capturedErrors -ErrorAction 'Ignore'
                    }
                    catch {
                        Write-Error "ERROR!! $_" -ErrorAction 'Stop'
                    }

                    $capturedErrors | foreach-object { if ($_ -notmatch "does not exist") { write-error $_ } }

                    Write-Host "`r`Stop App Pool m3_$($regionID)000 before deploying new files`r`n"

                    try {
                        Invoke-Command -ComputerName "$($nodes.name)" -ScriptBlock { Stop-WebAppPool -Name "m3_$($regionID)000" }
                    }
                    catch {
                        Write-Error "ERROR!! $_" -ErrorAction 'Continue'
                    }

                    Write-Host "`r`nExpanding uploaded zip files`r`n"

                    try {
                        Expand-Archive -LiteralPath "\\$($nodes.name)\e$\$($remotewebfolder)\$region.zip" -DestinationPath "\\$($nodes.name)\e$\$($remotewebfolder)"
                    }
                    catch {
                        Write-Error "ERROR!! $_" -ErrorAction 'Stop'
                    }

                    Write-Host "`r`Start App Pool m3_$($regionID)000 after deploying new files`r`n"

                    try {
                        Invoke-Command -ComputerName "$($nodes.name)" -ScriptBlock { Start-WebAppPool -Name "m3_$($regionID)000" }
                    }
                    catch {
                        Write-Error "ERROR!! $_" -ErrorAction 'Continue'
                    }

                    Write-Host "Attempting to unmount remote share \\$($nodes.name)\e$ ..."

                    net use \\$($nodes.name)\e$ /delete

                    Write-Host "`r`n========================================================================================================================`r`n"

                }
            }
        }
    }
}