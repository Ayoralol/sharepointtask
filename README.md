## #5 Site Generation Script

The scripts are written within respective folders:  
[./Script-one-set-hub/script.ps1](./Script-one-set-hub/script.ps1)  
[./Script-two-repeated-hub+benefits/script.ps1](./Script-two-repeated-hub+benefits/script.ps1)  
[./Script-three-one-hub+mult-benefits/script.ps1](./Script-three-one-hub+mult-benefits/script.ps1)

Script One - Generates x amount of Benefits sites while having a hard-coded HubSiteUrl within the template.xml
Script Two - Generate 1x Hub and 1x Benefits per "total site" count linked to each other
Script Three - Generates a single new Hub and x amount of Benefits sites all linked to that hub using {parameter:HubUrl}

Below is Script One

```Powershell
$templateFolderPath = "./source"
$templatePnpPath = "./template.pnp"
$totalSites = 10
$batchSize = 5
$sitePrefix = "cand05-S1"
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

Convert-PnPFolderToSiteTemplate -Folder $templateFolderPath -Out $templatePnpPath

for ($i = 0; $i -lt $totalSites; $i += $batchSize) {
    $end = [math]::Min($i + $batchSize, $totalSites)
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
                New-PnPSite -Type CommunicationSite -Url $siteUrl -Owner $adminEmail -Title $siteTitle -Description $siteDescription

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
    } -ArgumentList $i, $end, $sitePrefix, $templatePnpPath, $credPath
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
```

### Script Requirements

- Install-Module PnP.Powershell
- Install-Module ThreadJob

- Edit the script file to output the desired amount of sites and batch amounts
- **add credentials.xml to .gitignore**

## #6 On demand via Azure

To apply this template on demand via Azure, we could create a Function App on the Azure portal and make the runtime stack Powershell  
We could make this function a HTTP trigger and configure it to user a PowerShell script that applies the SharePoint template  
To use the same script that I wrote, I could edit it to accept parameters via the HTTP request  
Then deploy the script to the Azure function and trigger it with the HTTP request using the correct parameters

## #7 Azure solution on other systems

The Azure function triggered via HTTP endpoint makes it accessible through REST API calls, Allowing for integration with other apps/pipelines/automation tools

Azure Logic Apps can also connect to Sharepoint and create automated workflows that can create and apply templates to SharePoint sites based on events or schedules
