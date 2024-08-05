$templateFolderPath = "./source"
$templatexmlPath = "./source/template.xml"
$templatePnpPath = "./template.pnp"
$totalSites = 6
$batchSize = 2
$sitePrefix = "cand05-S3"
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
$hubUrl = "$spUrl/sites/${sitePrefix}HUB"
$initialUrl = "$spUrl/sites/${sitePrefix}0000"

Import-Module PnP.PowerShell
Import-Module ThreadJob
Connect-PnPOnline -Url $spUrl -Credentials $cred
Convert-PnPFolderToSiteTemplate -Folder $templateFolderPath -Out $templatePnpPath
Write-Host "Creating Initial Hub + Site and applying template"
New-PnPSite -Type CommunicationSite -Url $hubUrl -Owner $adminEmail -Title "$sitePrefix - HUB"
New-PnPSite -Type CommunicationSite -Url $initialUrl -Owner $adminEmail -Title "$sitePrefix 0000"
Start-Sleep -Seconds 5
Invoke-PnPTenantTemplate -Path $templatexmlPath -parameters @{
    "SiteTitle" = "$sitePrefix - HUB"
    "SiteUrl" = $hubUrl
    "BenefitsSiteTitle" = "$sitePrefix 0000"
    "BenefitsSiteUrl" = $initialUrl
    "HubUrl" = $hubUrl
    }
Write-Host "Created Initial Hub + Site and applied template"

for ($i = 1; $i -lt $totalSites; $i += $batchSize) {
    $end = [math]::Min($i + $batchSize, $totalSites)
    $jobs += Start-ThreadJob -ScriptBlock {
        param($start, $end, $sitePrefix, $templatePnpPath, $credPath, $hubUrl)

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

                Write-Host "Creating site: $siteUrl"
                New-PnPSite -Type CommunicationSite -Url $siteUrl -Owner $adminEmail -Title $siteTitle

                Write-Host "Created site: $siteUrl"
                Connect-PnPOnline -Url $siteUrl -Credentials $cred
                write-host "Connected"
                Start-Sleep -Seconds 5
                Invoke-PnPSiteTemplate -Path $templatePnpPath -parameters @{"HubUrl" = $hubUrl}
                Write-Host "Created and applied template to site: $sitePrefix$siteNumber"
            } catch {
                Write-Error "Error processing ${siteTitle}: $_"
            }
        }
    } -ArgumentList $i, $end, $sitePrefix, $templatePnpPath, $credPath, $hubUrl
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
