$templatexmlPath = "./source/template.xml" # Had to use .xml not .pnp as when sing .pnp it said Contoso-Financial-Calendar did not exist
$totalSites = 2 # Each makes 1 hub and 1 benefits
$batchSize = 1 # Batch size 1 creates all sites at once, Batch size as total creates one site at a time
$sitePrefix = "cand05-S2"
$credPath = "./credentials.xml"
$jobs = @()

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

for ($i = 0; $i -lt $totalSites; $i += $batchSize) {
    $end = [math]::Min($i + $batchSize, $totalSites)
    $jobs += Start-ThreadJob -ScriptBlock {
        param($start, $end, $sitePrefix, $templatexmlPath, $credPath)

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

                Write-Host "Creating site: ${siteUrl}-HUB"
                New-PnPSite -Type CommunicationSite -Url "${siteUrl}-HUB" -Owner $adminEmail -Title "$siteTitle HUB"
                Write-Host "Created site: ${siteUrl}-HUB"
                Write-Host "Creating site: $siteUrl"
                New-PnPSite -Type CommunicationSite -Url $siteUrl -Owner $adminEmail -Title $siteTitle
                Write-Host "Created site: $siteUrl"

                Connect-PnPOnline -Url "${siteUrl}-HUB" -Credentials $cred
                Write-Host "Connected to ${siteUrl}-HUB"
                Write-Host "Applying template to sites: ${siteUrl}-HUB and $siteUrl"
                Start-Sleep -Seconds 5
                Invoke-PnPTenantTemplate -Path $templatexmlPath -Parameters @{
                    "SiteTitle" = "$siteTitle HUB"
                    "SiteUrl" = "${siteUrl}-HUB"
                    "BenefitsSiteTitle" = $siteTitle
                    "BenefitsSiteUrl" = $siteUrl
                }
                Write-Host "Applied template to sites: ${siteUrl}-HUB and $siteUrl"
            } catch {
                Write-Error "Error processing ${siteTitle}: $_"
            }
        }
    } -ArgumentList $i, $end, $sitePrefix, $templatexmlPath, $credPath
}

$jobs | ForEach-Object {
    $jobResult = $_ | Receive-Job -Wait -AutoRemoveJob

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
