###############################################################
# Site configuration
# Change the next 2 lines to your site info 
$SiteCode = "ABC" # Site code 
$ProviderMachineName = "SITESERVER" # SMS Provider machine name
###############################################################
# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

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

# User Notification
Write-Host "This script is used to copy, cancel current deployments, and retire a target application" -ForegroundColor Magenta
$LogPath = "$PSScriptRoot\MECMCustomScript.log"
Write-Host "Logging can be found at $LogPath" -ForegroundColor Magenta

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

# Get Application Function
Function Get-SCCMApplication($name) {
    $smsApp = Get-CMApplication -Name $name
    $currSDMobj = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($smsapp.SDMPackageXML)
    return $currSDMobj
 }

# Set Application Function
Function Set-SCCMApplication($name, $app) {
    $smsApp = Get-CMApplication -Name $name
    $currSDMXmlNew = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::SerializeToString($app)
    $smsApp.SDMPackageXML = $currSDMXmlNew                                                                            
    Set-CMApplication -InputObject $smsApp | Out-Null
 }

 # Copy Application
function Copy-SCCMApplication {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Source,
        [Parameter(Position=1)]
        [System.String]
        $Destination = "$Source - Copy"        
    )

    New-CMApplication -Name $Destination
    $oldSDM = Get-SCCMApplication -name $Source
    $newSDM = Get-SCCMApplication -name $Destination
    $newSDM.CopyFrom($oldSDM)
    $newSDM.DeploymentTypes.ChangeId()
    $newSDM.Title = $Destination
    Set-SCCMApplication -name $Destination -app $newSDM   
  }


# Get the name of the application to retire
$AppName = Read-Host "Target Application"

# Copy Application
# Copies Application to the top level of Applications in Console
$AppCopy = Read-Host "Copy Application before cancelling deployments? (y/n)"
if ($AppCopy -eq "y") {
    try {
        Write-Host "Copying $AppName..." -ForegroundColor Yellow
        Write-Progress -Activity "Please wait for $AppName to be copied" -Status "Creating $AppName - copy"
        $CopiedApp = Copy-SCCMApplication -Source $AppName
        Write-Progress -Activity "Please wait for $AppName to be copied" -Status "Creating $AppName - copy" -Completed
        Write-Host  "$AppName - copy created succesfully" -ForegroundColor Green
        Write-Log -Message "$AppName - copy created succesfully" -Severity 1 -Component "App Deploy Cancel"
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "App Deploy Cancel"
    }
}

# Move Application to Folder 
# If you do not use folders just get rid of this whole thing. Please insert your own site code to make it work
$MoveApp = Read-Host "Move $AppName - Copy to an application folder (y/n)"
if ($MoveApp -eq "y") {
    try {
        $StartProgress = 0
        $EndProgress = 2
        Write-Host "Parsing Application Folders" -ForegroundColor Yellow
        Write-Progress -Activity "Parsing Application Folders"
        
        # Make the path applicable for your site code
        $AvailableFolders = Get-ChildItem -Path "ABC:\Application" | Select-Object -Property Name
        
        Write-Progress -Activity "Parsing Application Folders" -Completed
        Format-Table -InputObject $AvailableFolders
        $TargetFolder = Read-Host "Target Folder"
        $StartProgress++
        Write-Progress -Activity "Moveing $AppName - Copy  to $TargetFolder" -Status "Gathering information variables..." -PercentComplete ($StartProgress / $EndProgress *100) 
       
        $MoveObject = Get-CMApplication -Name "$AppName - Copy"
        $StartProgress++
        Write-Progress -Activity "Moveing $AppName - Copy  to $TargetFolder" -Status "Moving Object..." -PercentComplete ($StartProgress / $EndProgress *100) 
        
        # Make the path applicable for your site code
        Move-CMObject -FolderPath "ABC:\Application\$TargetFolder" -InputObject $MoveObject
        Write-Progress -Activity "Moveing $AppName - Copy  to $TargetFolder" -Completed
        Write-Host  "$AppName - Copy moved succesfully" -ForegroundColor Green
        
        # Insert Site Code
        Write-Log -Message "$AppName - Copy moved to ABC:\Application\$TargetFolder" -Severity 1 -Component "App Deploy Cancel"
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "App Deploy Cancel"
    }
}


# Get all active deployments for the application
Write-Progress -Activity "Parsing Deploymnets..."
$Deployments = Get-CMApplicationDeployment -Name $AppName 
Write-Progress -Activity "Parsing Deployments..." -Completed

$Count = 0
# Cancel all deployments
foreach ($Deployment in $Deployments) {
    $Count++
    try{
        $CollectionName = $Deployment.CollectionName
        Write-Progress -Activity "Stopping $($Deployment.ApplicationName) deployment on $CollectionName" -Status "Stopping $Count of $($Deployments.Count) ..." -PercentComplete ($Count / $Deployments.count * 100)
        Write-Progress -Activity "Stopping $($Deployment.ApplicationName) deployment on $CollectionName" -Status "Stopping $Count of $($Deployments.Count) ..." -PercentComplete ($Count / $Deployments.count * 100)
        Remove-CMApplicationDeployment -Name "$AppName" -CollectionName "$CollectionName" -Force
        Write-Host "Cancelled deployment for $($Deployment.ApplicationName) on collection $CollectionName" -ForegroundColor Green
        Write-Log -Message "Cancelled deployment for $($Deployment.ApplicationName) on collection $CollectionName" -Severity 1 -Component "App Deploy Cancel"
    }
    catch{
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "App Deploy Cancel"
    }
}


# Retire the application
Write-Progress -Activity "Retiring $AppName..."
Suspend-CMApplication -Name $AppName
Write-Host "Retired application $AppName" -ForegroundColor Green
Write-Progress -Activity "Retiring $AppName..." -Completed
Write-Log -Message "Retired application $AppName" -Severity 1 -Component "App Deploy Cancel"

# Exit
Write-Host "Exiting..." -ForegroundColor Green
Set-Location $PSScriptRoot
