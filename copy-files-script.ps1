# General file copying script
Param(
    [ValidateNotNullOrEmpty()]
    [string]$pipeline = "lms-build-dev-2021",
    [ValidateNotNullOrEmpty()]
    [string]$workspacefolder = "E:\drop\workspace",
    [ValidateNotNullOrEmpty()]
    [string]$dropfolder = "E:\drop\bin",
    [ValidateNotNullOrEmpty()]
    [string]$transitfolder = "E:\transit",
    [ValidateNotNullOrEmpty()]
    [string[]]$regions,
    [ValidateNotNullOrEmpty()]
    [string]$environment = "dev",
    [ValidateNotNullOrEmpty()]
    [string]$serversfile = "E:\Tools\Scripts\lms-servers.json"
)

# $pipeline         e.g lms-build-dev-2021 (pipeline project name)
# $workspacefolder  e.g E:\drop\workspace (jenkins default workspace folder)
# $dropfolder       e.g E:\drop\bin
# $transitfolder    e.g E:\transit
# $region           e.g 01.Americas (also known as Instance)
# $environment      e.g dev, qa or prod
# $serversfile      e.g E:\Tools\Scripts\lms-servers.json

Write-Host "`r`nDEPLOYMENT STARTED"

$data = Get-Content -Raw -Path $serversfile | ConvertFrom-Json

$servers = $data.servers

$workspacepath = "$workspacefolder\$pipeline\Source\Amway.Learning.Mobile"

$droppath = "$dropfolder\$pipeline\Release\_PublishedWebsites"

$transitpath = "$transitfolder\$environment\Web\LMSMobile"

# Delete old zip files
Write-host "`r`nStep $region - 00 : Deleting old zip files from $transitpath`r`n"

Get-ChildItem "$transitpath" -Recurse -File -Include "*.zip" | Remove-Item -Force -ErrorVariable capturedErr

$capturedErr | foreach-object { if ($_ -notmatch "does not exist") { write-error $_ } }

Write-host "`r`nCleaning up $transitpath before copying`r`n"

Remove-Item "$transitpath\*" -Recurse -ErrorVariable capturedErrors -ErrorAction 'Ignore'

$capturedErrors | foreach-object { if ($_ -notmatch "does not exist") { write-error $_ } }

foreach ($region in $regions) {

    $regionID = $region.substring(0,2)

    Write-Host "`r`n========================================================================================================================`r`n"
    Write-Host "`r`START COPYING FILES to $regionID ( $region )`r`n"
    Write-Host "`r`n========================================================================================================================"


    $solutions = @('Amway.Learning.Mobile.Admin.Website','Amway.Learning.Mobile.WebAPI','Amway.Learning.Mobile.Website','Amway.Learning.ILTInstructor.Website','Amway.Learning.Schedular')

    # Create transit folder if it doesn't exists
    Write-host "`r`nStep $region - 02 : Recreating folders inside $transitpath\$region`r`n"

    foreach ($solution in $solutions)
    {
        Write-host "`r`nStep $region - 02.1 - $solution : Creating $transitpath\$region\$solution\ folder ...`r`n"

        try {
            md -f "$transitpath\$region\$solution\" -ErrorAction 'Stop'
        }
        catch {
            Write-Error "ERROR!! $_" -ErrorAction 'Stop'
        }

        # Start copying files to transit folders in slave USNT00640
        # Copy LMS files from build folder to instance transit folder
        if ($solution -ne 'Amway.Learning.Schedular')
        {

            Write-Host "`r`nStep $region - 03 - $solution : Copying files from $droppath to $transitpath\$region\$solution`r`n"

            try {
                Copy-Item -Path "$droppath\*" -Destination "$transitpath\$region" -Recurse -Force -ErrorAction 'Stop'
            }
            catch {
                Write-Error "ERROR!! $_" -ErrorAction 'Stop'
            }

        } else {

            Write-Host "`r`nStep $region - 03.1 - $solution : Copy files from $dropfolder\$pipeline\Schedular\* to instance transit folder $transitpath\$region\$solution`r`n"

            try {
                Copy-Item -Path "$dropfolder\$pipeline\Scheduler\*" -Destination "$transitpath\$region\$solution" -Recurse -Force -ErrorAction 'Stop'
            }
            catch {
                Write-Error "ERROR!! $_" -ErrorAction 'Stop'
            }

        }

        # Copy Amway.Learning.Data.SQLServer.dll to instance transit folder Amway.Learning.Mobile.Admin.Website\bin\ & Amway.Learning.Mobile.WebAPI\bin\
        if ($solution -eq 'Amway.Learning.Mobile.Admin.Website' -or $solution -eq 'Amway.Learning.Mobile.WebAPI')
        {
            Write-Host "`r`nStep $region - 04 - $solution : Remove $transitpath\$region\$solution\bin\Amway.Learning.Data.SQLServer.dll`r`n"

            try {

                Remove-Item -LiteralPath "$transitpath\$region\$solution\bin\Amway.Learning.Data.SQLServer.dll" -Force

            }
            catch {

                Write-Error "ERROR!! $_" -ErrorAction 'Stop'

            }

            Write-Host "`r`nStep $region - 04.1 - $solution : Copy $dropfolder\$pipeline\Release\Amway.Learning.Data.SQLServer.dll to instance transit folder $transitpath\$region\$solution\bin\`r`n"

            try {

                Copy-Item -Path "$dropfolder\$pipeline\Release\Amway.Learning.Data.SQLServer.dll" -Destination "$transitpath\$region\$solution\bin\" -Recurse -Force -ErrorAction 'Stop'

            }
            catch {

                Write-Error "ERROR!! $_" -ErrorAction 'Stop'

            }

        }

        # Copy Config files from working folder to instance transit folder
        if ($solution -eq 'Amway.Learning.Mobile.Admin.Website' -or $solution -eq 'Amway.Learning.Mobile.WebAPI' -or $solution -eq 'Amway.Learning.Schedular' -or $solution -eq 'Amway.Learning.ILTInstructor.Website')
        {
            Write-Host "`r`nStep $region - 05 - $solution : Remove Config files from $transitpath\$region\$solution\Config  folder`r`n"

            try {

                Rename-Item "$transitpath\$region\$solution\Config" "$transitpath\$region\$solution\Config-old"

            }
            catch {

                Write-Error "ERROR!! $_" -ErrorAction 'Stop'

            }

            Start-Sleep -Seconds 5

            Write-Host "`r`nStep $region - 05.1 - $solution : Copy Config files from $workspacepath\configuration\$environment\instance$regionID to instance transit folder $transitpath\$region\$solution\Config`r`n"

            try {

                Copy-Item -Path "$workspacepath\configuration\$environment\instance$regionID" -Destination "$transitpath\$region\$solution\Config" -Recurse -Force -ErrorAction 'Stop'

            }
            catch {

                Write-Error "ERROR!! $_" -ErrorAction 'Stop'

            }

        }

        Write-Host "`r`n========================================================================================================================`r`n"
    }

    # Copy Dynatrace files from working folder to instance transit folder
    Write-Host "`r`nStep $region - 06 - Amway.Learning.Mobile.Website: Remove Dynatrace files from $transitpath\$region\Amway.Learning.Mobile.Website\Custom folder`r`n"

    try {

        Remove-Item "$transitpath\$region\Amway.Learning.Mobile.Website\Custom" -Force -Recurse

    }
    catch {

        Write-Error "ERROR!! $_" -ErrorAction 'Stop'

    }

    Start-Sleep -Seconds 5

    Write-Host "`r`nStep $region - 06.1 - Amway.Learning.Mobile.Website: Copy Dynatrace files from $workspacepath\Custom\$environment\instance$regionID to instance transit folder $transitpath\$region\Amway.Learning.Mobile.Website\Custom`r`n"

    try {

        Copy-Item -Path "$workspacepath\Custom\$environment\instance$regionID" -Destination "$transitpath\$region\Amway.Learning.Mobile.Website\Custom" -Recurse

    }
    catch {

        Write-Error "ERROR!! $_" -ErrorAction 'Stop'

    }

    # Zip folder recursively by region
    Write-Host "`r`nStep $region - 07 : Zip $region folder`r`n"

    Compress-Archive -Path "$transitpath\$region" -DestinationPath "$transitpath\$region.zip"
    # Compress-Archive -Path "$transitpath\$region" -DestinationPath "$transitpath\$region-$((Get-Date).ToString('yyyy_MM_dd-hh_mm_ss')).zip"

}