$templateFolderPath = "./source"
$templatePnpPath = "./template.pnp"
$totalSites = 10
$batchSize = 5
$sitePrefix = "cand05-S1"
$credPath = "./credentials.xml"
$jobs = @()
$jobDefinitions = @()

function Get-Stored-Credential {
    param (
        [string]$credFilePath
    )
    if (-Not (Test-Path -Path $credFilePath)) {
        $cred = Get-Credential
        $spUrl = Read-Host "Enter SharePoint URL"
        $credHash = @{
            Credential = $cred
            SharePointUrl = $spUrl
        }
        $credHash | Export-Clixml -Path $credFilePath
    } else {
        Write-Host "Using stored credentials from $credFilePath"
    }
}

Get-Stored-Credential -credFilePath $credPath

$storedCreds = Import-Clixml -Path $credPath
$cred = $storedCreds.Credential
$spUrl = $storedCreds.SharePointUrl

Import-Module PnP.PowerShell
Import-Module ThreadJob
Connect-PnPOnline -Url $spUrl -Credentials $cred

Convert-PnPFolderToSiteTemplate -Folder $templateFolderPath -Out $templatePnpPath

for ($i = 0; $i -lt $totalSites; $i += $batchSize) {
    $end = [math]::Min($i + $batchSize, $totalSites)
    $jobDefinitions += [PSCustomObject]@{
        Start = $i
        End = $end
        SitePrefix = $sitePrefix
        TemplatePnpPath = $templatePnpPath
        CredPath = $credPath
    }
}

foreach ($jobDef in $jobDefinitions) {
    $jobs += Start-ThreadJob -ScriptBlock {
        param($start, $end, $sitePrefix, $templatePnpPath, $credPath)

        $storedCreds = Import-Clixml -Path $credPath
        $cred = $storedCreds.Credential
        $adminEmail = $cred.UserName
        $spUrl = $storedCreds.SharePointUrl
        Connect-PnPOnline -Url $spUrl -Credentials $cred

        for ($j = $start; $j -lt $end; $j++) {
            try {
                $siteNumber = "{0:D4}" -f $j
                $siteUrl = "$spUrl/sites/$sitePrefix$siteNumber"
                $siteTitle = "$sitePrefix $siteNumber"
                $siteDescription = "Site $sitePrefix number $siteNumber"

                Write-Host "Creating site: $siteUrl"
                New-PnPSite -Type CommunicationSite -Url $siteUrl -Owner $adminEmail -Title $siteTitle

                Write-Host "Created site: $siteUrl"
                Connect-PnPOnline -Url $siteUrl -Credentials $cred
                write-host "Connected"
                Start-Sleep -Seconds 5
                Invoke-PnPSiteTemplate -Path $templatePnpPath
                Write-Host "Created and applied template to site: $sitePrefix$siteNumber"
            } catch {
                Write-Error "Error processing ${siteTitle}: $_"
            }
        }
    } -ArgumentList $jobDef.Start, $jobDef.End, $jobDef.SitePrefix, $jobDef.TemplatePnpPath, $jobDef.CredPath
}

Wait-Job -Job $jobs

$jobs | ForEach-Object {
    $jobResult = $_ | Receive-Job -AutoRemoveJob

    if ($_.State -eq 'Completed') {
        Write-Host "Job $($_.Id) completed successfully."
    } else {
        $jobError = $_ | Get-Job | Select-Object -ExpandProperty Error
        if ($jobError) {
            Write-Error "Job $($_.Id) failed with error: $jobError"
        } else {
            Write-Error "Job $($_.Id) failed but no error message is available."
        }
    }
}

Write-Host "Completed Script and Disconnected"
