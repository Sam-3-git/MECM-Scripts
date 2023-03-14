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
Write-Host "This script is used to tranfer update membership from one SUG to another" -ForegroundColor Magenta
$LogPath = "$PSScriptRoot\MECMCustomScript.log"
Write-Host "Logging can be found at $LogPath" -ForegroundColor Magenta

# Create New SUG 
$NewSUG = Read-Host "Do you want to create a new SUG? (y/n)" 
if ($NewSUG -eq "y"){
    Try {
        $NewSUGName = Read-Host "New SUG name?"
        $SUGDescription = "Created by MECM Custom Script SUGMemberTranfer"
        Write-Progress -Activity "Creating $NewSUGName" 
        $CreateSUG = New-CMSoftwareUpdateGroup -Name $NewSUGName -Description $SUGDescription
        Write-Progress -Activity "Creating $NewSUGName" -Completed
        Write-Log -Message "Created $NewSUGName" -Severity 1 -Component "SUG Member Transfer"
    }
    Catch {
        Write Warning "$_.Exception.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Member Transfer"
    }
}

# Get SUGs
Write-Host "Loading Available SUGs..." -ForegroundColor Green
$SUGList = Get-CMSoftwareUpdateGroup | Select-Object LocalizedDisplayName,DateCreated | Sort-Object DateCreated 
Format-Table -InputObject $SUGList

# Gets Source SUG
$SourceSUG = Read-Host "Source SUG Name?"
$TargetSUG = Read-Host "Target SUG Name?"

# Get Source SUG Members
Write-Host "Gathering Updates from $SourceSUG" -ForegroundColor Green
Write-Progress -Activity "Gathering Updates from $SourceSUG" 
$Updates = Get-CMSoftwareUpdate -UpdateGroupName $SourceSUG -Fast
Write-Progress -Activity "Gathering Updates from $SourceSUG"  -Completed
$Count = 0

# Tranfer Members from SUG
Foreach ($Update in $Updates) {
    $Count++
    Try {
        Write-Progress -Activity "Adding $($Update.LocalizedDisplayName) to $TargetSUG" -Status "Adding $Count of $($Updates.Count) updates to $TargetSUG" -PercentComplete ($Count / $Updates.count * 100)
        Add-CMSoftwareUpdateToGroup -SoftwareUpdateId $Update.CI_ID -SoftwareUpdateGroupName $TargetSUG 
        Write-Log -Message "Adding $($Update.LocalizedDisplayName) to $TargetSUG" -Severity 1 -Component "SUG Member Transfer"
    }
    Catch {
        Write Warning "$_.Exception.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Member Transfer"
    }
}

# Remove updates from Source SUG
$RemoveInput = Read-Host "Do you want to remove updates from $SourceSUG ? (y/n)"
$Count = 0
if ($RemoveInput -eq "y"){
    Foreach ($Update in $Updates) {
    $Count++
    Try {
        Write-Progress -Activity "Removing $($Update.LocalizedDisplayName) from $SourceSUG" -Status "Removing $Count of $($Updates.Count) updates from $SourceSUG" -PercentComplete ($Count / $Updates.count * 100)
        Remove-CMSoftwareUpdateFromGroup -SoftwareUpdateId $Update.CI_ID -SoftwareUpdateGroupName $SourceSUG -Force
        Write-Log -Message "Removing $($Update.LocalizedDisplayName) from $SourceSUG" -Severity 1 -Component "SUG Member Transfer"
    }
    Catch {
        Write Warning "$_.Exception.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Member Transfer"
    }
}  
}

# Remove Source SUG
$RemoveSUG = Read-Host "Do you want to remove $SourceSUG ? (y/n)"
$Count = 0
if ($RemoveSUG -eq "y"){
    try {
        Write-Host "Removing $SourceSUG ..." -ForegroundColor Yellow
        Write-Progress -Activity "Removing $SourceSUG"
        Remove-CMSoftwareUpdateGroup -Name $SourceSUG -Force
        Write-Progress -Activity "Removing $SourceSUG" -Completed
        Write-Host "$SourceSUG removed." -ForegroundColor Green
        Write-Log -Message "Removed $SourceSUG" -Severity 1 -Component "SUG Member Transfer"
    }
    catch {
        Write Warning "$_.Execption.Message"
        Write-Log -Message "$_.Exception.Message" -Severity 3 -Component "SUG Member Transfer"
    }
}

# Exit
Write-Host "Exiting..." -ForegroundColor Green
Set-Location $PSScriptRoot
