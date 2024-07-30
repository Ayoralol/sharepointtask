## #2 Initial template

[Initial Template Link](https://forvbtnd.sharepoint.com/sites/05template)

## #3 + #4 PR/Merge to Github

[Github PR](https://github.com/Ayoralol/sp-dev-provisioning-templates/pull/1)

## #5 Site Generation Script

The script is written within [./tenant/contosoworks/script.ps1](./tenant/contosoworks)

The script is written to be able to be used with any template, simply move the script into the folder above /source/ that contains your template.xml  
It will take the /source/ folder and create a template.pnp out of it, upload the template to "Shared Documents" on SharePoint, and use that to apply to the sites.  
The script first prompts your credentials and creates a credentials.xml file within the same folder as the script, and can then be used on subsequent executions

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
