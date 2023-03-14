# Site configuration; change for your enviorment
###############################################################
$SiteCode = "ABC" # Site code 
$ProviderMachineName = "SITESERVER" # SMS Provider machine name
# Manual input needed in script futher down...
###############################################################


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
Write-Host "This script is used to Deploy Software Updates to Collections" -ForegroundColor Magenta
$LogPath = "$PSScriptRoot\MECMCustomScript.log"
Write-Host "Logging can be found at $LogPath" -ForegroundColor Magenta

######################################################################
# Optional Variables. Add desired collections to list if you want this script to be fast. 
$CommonCollections = "Workstation - Production", "Server - Production"
# User Driven Variables
# Can use Get-CMCollection | Select-Object Property | Where-Object {Conditions}if desired, but it is a very slow command
# Collection Choices
Write-Host "Loading Common Collections..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Common Collections"
Write-Host "------------------"
foreach ($Collection in $CommonCollections) {
    Write-Host $Collection 
}
######################################################################

Write-Host ""
Write-Host ""
$TargetCollection = Read-Host "Target Collection Name"
Write-Host "Loading Available SUGs..." -ForegroundColor Yellow
Write-Progress -Activity "Querying SUGs..."
$SUGList = Get-CMSoftwareUpdateGroup | Select-Object LocalizedDisplayName,DateCreated | Sort-Object DateCreated 
Write-Progress -Activity "Querying SUGs..." -Completed
Format-Table -InputObject $SUGList
$TargetSUG = Read-Host "SUG for Deploymnet"

# Deploymnet Choices
Write-Host ""
Write-Host "Deployment Choice"
Write-Host "-----------------"
Write-Host "$TargetSUG deploy to $TargetCollection" -ForegroundColor Green
$DeploymentTypeList = "[1] Required", "[2] Avialable"
Write-Host "Loading Deployment Types..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Deployment Options"
Write-Host "------------------"
foreach ($Deployment in $DeploymentTypeList) {
    Write-Host $Deployment
}
Write-Host ""
Write-Host ""
$DeploymentType = Read-Host "Select Deployment Number"
# Deploymnet Methods
if ($DeploymentType -eq "1") {
    try {
        # Variables
        $DeploymentName = "$TargetSUG : $TargetCollection"
        $Description = "Custom Script Deployment"
        $RightNow = Get-Date
        Write-Host "Deploying $TargetSUG to $TargetCollection ..." -ForegroundColor Yellow
        Write-Progress -Activity "Please wait for the Deployment to be created..." -Status "Deploying $TargetSUG to $TargetCollection"
        $NewDeployment = New-CMSoftwareUpdateDeployment -DeploymentName $DeploymentName -SoftwareUpdateGroupName $TargetSUG -CollectionName $TargetCollection -Description $Description -DeploymentType Required -VerbosityLevel OnlySuccessAndErrorMessages -AvailableDateTime $RightNow -DeadlineDateTime $RightNow -UserNotification DisplayAll -SoftwareInstallation $True  -AllowRestart $False -PersistOnWriteFilterDevice $True -RequirePostRebootFullScan $True -DownloadFromMicrosoftUpdate $False
        Write-Progress -Activity "Please wait for the Deployment to be created..." -Status "Deploying $TargetSUG to $TargetCollection" -Completed
        Write-Host  "Deployment created succesfully" -ForegroundColor Green
        Write-Log -Message "$TargetSUG succesfully deployed to $TargetCollection" -Severity 1 -Component "SUG Deployment"
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Deployment"
    }
}

if ($DeploymentType -eq "2") {
    try {# Variables
        $DeploymentName = "$TargetSUG : $TargetCollection"
        $Description = "Custom Script Deployment"
        $RightNow = Get-Date
        Write-Host "Deploying $TargetSUG to $TargetCollection ..." -ForegroundColor Yellow
        Write-Progress -Activity "Please wait for the Deployment to be created..." -Status "Deploying $TargetSUG to $TargetCollection"
        $NewDeployment = New-CMSoftwareUpdateDeployment -DeploymentName $DeploymentName -SoftwareUpdateGroupName $TargetSUG -CollectionName $TargetCollection -Description $Description -DeploymentType Available -VerbosityLevel OnlySuccessAndErrorMessages -UserNotification DisplayAll -RequirePostRebootFullScan $True -DownloadFromMicrosoftUpdate $False
        Write-Progress -Activity "Please wait for the Deployment to be created..." -Status "Deploying $TargetSUG to $TargetCollection" -Completed
        Write-Host  "Deployment created succesfully" -ForegroundColor Green
        Write-Log -Message "$TargetSUG succesfully deployed to $TargetCollection" -Severity 1 -Component "SUG Deployment"
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Deployment"
    }
}

# Exit
Write-Host "Exiting..." -ForegroundColor Green
Set-Location $PSScriptRoot


