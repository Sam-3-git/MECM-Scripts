# Site configuration
$SiteCode = "ABC" # Site code 
$ProviderMachineName = "SITESERVER" # SMS Provider machine name


# Customizations
$initParams = @{}
# $initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
# $initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

# Logging Function
Function Write-Log
{
 
    PARAM(
        [String]$Message,
        [int]$Severity,
        [string]$Component
    )
        $LogPath = $PSScriptRoot
        $TimeZoneBias = Get-WMIObject -Query "Select Bias from Win32_TimeZone"
        $Date= Get-Date -Format "HH:mm:ss.fff"
        $Date2= Get-Date -Format "MM-dd-yyyy"
        $Type=1
         
        "<![LOG[$Message]LOG]!><time=$([char]34)$Date$($TimeZoneBias.bias)$([char]34) date=$([char]34)$date2$([char]34) component=$([char]34)$Component$([char]34) context=$([char]34)$([char]34) type=$([char]34)$Severity$([char]34) thread=$([char]34)$([char]34) file=$([char]34)$([char]34)>"| Out-File -FilePath "$LogPath\MECMCustomScript.log" -Append -NoClobber -Encoding default
}

# User Notification
Write-Host "This script is used to mass deploy a target SUG to Production Collections as Required" -ForegroundColor Magenta
$LogPath = "$PSScriptRoot\MECMCustomScript.log"
Write-Host "Logging can be found at $LogPath" -ForegroundColor Magenta

# Optional Variables
# Can use Get-CMCollection | Select-Object Property | Where-Object {Conditions}if desired, but it is a very slow command
$ProdCollections = "Workstation - Production", "Azure - Production"

# User Driven Variables
# Can use Get-CMCollection | Select-Object Property | Where-Object {Conditions}if desired, but it is a very slow command
# Collection Choices
Write-Host "Loading Production Collections..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Production Collections"
Write-Host "----------------------"
foreach ($Collection in $ProdCollections) {
    Write-Host $Collection 
}
Write-Host ""
Write-Host ""
Write-Host "Loading Available SUGs..." -ForegroundColor Yellow
Write-Progress -Activity "Querying SUGs..."
$SUGList = Get-CMSoftwareUpdateGroup | Select-Object LocalizedDisplayName,DateCreated | Sort-Object DateCreated 
Write-Progress -Activity "Querying SUGs..." -Completed
Format-Table -InputObject $SUGList
$TargetSUG = Read-Host "SUG for Mass Deploymnet"

# Mass Production Deployment
$Count = 0 
Write-Host "Deploying $TargetSUG to Production ..." -ForegroundColor Yellow
foreach ($Collection in $ProdCollections) {
    $Count++
    try {# Variables
        $DeploymentName = "$TargetSUG : $Collection"
        $Description = "Custom Script Deployment"
        $RightNow = Get-Date
        $RightNowThreeDaysLater = (Get-Date).AddDays(3)
        Write-Progress -Activity "Deploying $TargetSUG to $Collection" -Status "Deploying $Count of $($ProdCollections.Count) ..." -PercentComplete ($Count / $ProdCollections.count * 100)
        $NewDeployment = New-CMSoftwareUpdateDeployment -DeploymentName $DeploymentName -SoftwareUpdateGroupName $TargetSUG -CollectionName $Collection -Description $Description -DeploymentType Required -VerbosityLevel OnlySuccessAndErrorMessages -AvailableDateTime $RightNow -DeadlineDateTime $RightNowThreeDaysLater -UserNotification DisplayAll -SoftwareInstallation $True  -AllowRestart $True -RestartServer $False -PersistOnWriteFilterDevice $True -RequirePostRebootFullScan $True -DownloadFromMicrosoftUpdate $False -UseMeteredNetwork $True 
        Write-Log -Message "$TargetSUG succesfully deployed to $Collection" -Severity 1 -Component "Mass Deploy"
        Write-Host "$TargetSUG succesfully deployed to $Collection" -ForegroundColor Green
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "Mass Deploy"
    }
}

# Exit
Write-Host "Exiting..." -ForegroundColor Green
Set-Location $PSScriptRoot
       
