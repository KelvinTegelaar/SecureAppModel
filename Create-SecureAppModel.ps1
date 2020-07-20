Param
(
    [Parameter(Mandatory = $false)]
    [switch]$ConfigurePreconsent,
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,
    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

$ErrorActionPreference = "Stop"

# Check if the Azure AD PowerShell module has already been loaded.
if ( ! ( Get-Module AzureAD ) ) {
    # Check if the Azure AD PowerShell module is installed.
    if ( Get-Module -ListAvailable -Name AzureAD ) {
        # The Azure AD PowerShell module is not load and it is installed. This module
        # must be loaded for other operations performed by this script.
        Write-Host -ForegroundColor Green "Loading the Azure AD PowerShell module..."
        Import-Module AzureAD
    } else {
        Install-Module AzureAD
    }
}

try {
    Write-Host -ForegroundColor Green "When prompted please enter the appropriate credentials... Warning: Window might have pop-under in VSCode"

    if([string]::IsNullOrEmpty($TenantId)) {
        Connect-AzureAD | Out-Null

        $TenantId = $(Get-AzureADTenantDetail).ObjectId
    } else {
        Connect-AzureAD -TenantId $TenantId | Out-Null
    }
} catch [Microsoft.Azure.Common.Authentication.AadAuthenticationCanceledException] {
    # The authentication attempt was canceled by the end-user. Execution of the script should be halted.
    Write-Host -ForegroundColor Yellow "The authentication attempt was canceled. Execution of the script will be halted..."
    Exit
} catch {
    # An unexpected error has occurred. The end-user should be notified so that the appropriate action can be taken.
    Write-Error "An unexpected error has occurred. Please review the following error message and try again." `
        "$($Error[0].Exception)"
}

$adAppAccess = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId = "00000002-0000-0000-c000-000000000000";
    ResourceAccess =
    [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id = "5778995a-e1bf-45b8-affa-663a9f3f4d04";
        Type = "Role"},
    [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id = "a42657d6-7f20-40e3-b6f0-cee03008a62a";
        Type = "Scope"},
    [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6";
        Type = "Scope"}
}

$graphAppAccess = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId = "00000003-0000-0000-c000-000000000000";
    ResourceAccess =
        [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "bf394140-e372-4bf9-a898-299cfc7564e5";
            Type = "Role"},
        [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61";
            Type = "Role"}
}

$partnerCenterAppAccess = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId = "fa3d9a0c-3fb0-42cc-9193-47c7ecd2edbd";
    ResourceAccess =
        [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "1cebfa2a-fb4d-419e-b5f9-839b4383e05a";
            Type = "Scope"}
}

$SessionInfo = Get-AzureADCurrentSessionInfo

Write-Host -ForegroundColor Green "Creating the Azure AD application and related resources..."

$app = New-AzureADApplication -AvailableToOtherTenants $true -DisplayName $DisplayName -IdentifierUris "https://$($SessionInfo.TenantDomain)/$((New-Guid).ToString())" -RequiredResourceAccess $adAppAccess, $graphAppAccess, $partnerCenterAppAccess -ReplyUrls @("urn:ietf:wg:oauth:2.0:oob","https://localhost","http://localhost","http://localhost:8400")
$password = New-AzureADApplicationPasswordCredential -ObjectId $app.ObjectId
$spn = New-AzureADServicePrincipal -AppId $app.AppId -DisplayName $DisplayName


    $adminAgentsGroup = Get-AzureADGroup -Filter "DisplayName eq 'AdminAgents'"
    Add-AzureADGroupMember -ObjectId $adminAgentsGroup.ObjectId -RefObjectId $spn.ObjectId

write-host "Installing PartnerCenter Module." -ForegroundColor Green
install-module PartnerCenter -Force
write-host "Sleeping for 30 seconds to allow app creation on O365" -foregroundcolor green
start-sleep 30
write-host "Please approve General consent form." -ForegroundColor Green
$PasswordToSecureString = $password.value | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($($app.AppId),$PasswordToSecureString)
$token = New-PartnerAccessToken -ApplicationId "$($app.AppId)" -Scopes 'https://api.partnercenter.microsoft.com/user_impersonation' -ServicePrincipal -Credential $credential -Tenant $($spn.AppOwnerTenantID) -UseAuthorizationCode
write-host "Please approve Exchange consent form." -ForegroundColor Green
$Exchangetoken = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716' -Scopes 'https://outlook.office365.com/.default' -Tenant $($spn.AppOwnerTenantID) -UseDeviceAuthentication
write-host "Please approve Azure consent form." -ForegroundColor Green
$Azuretoken = New-PartnerAccessToken -ApplicationId "$($app.AppId)" -Scopes 'https://management.azure.com/user_impersonation' -ServicePrincipal -Credential $credential -Tenant $($spn.AppOwnerTenantID) -UseAuthorizationCode
write-host "Last initation required: Please browse to https://login.microsoftonline.com/$($spn.AppOwnerTenantID)/adminConsent?client_id=$($app.AppId)"
write-host "Press any key after auth. An error report about incorrect URIs is expected!"
[void][System.Console]::ReadKey($true)
Write-Host "######### Secrets #########"
Write-Host "`$ApplicationId         = '$($app.AppId)'"
Write-Host "`$ApplicationSecret     = '$($password.Value)'"
Write-Host "`$TenantID              = '$($spn.AppOwnerTenantID)'"
write-host "`$RefreshToken          = '$($token.refreshtoken)'" -ForegroundColor Blue
write-host "`$ExchangeRefreshToken = '$($ExchangeToken.Refreshtoken)'" -ForegroundColor Green
write-host "`$AzureRefreshToken =   '$($Azuretoken.Refreshtoken)'" -ForegroundColor Magenta
Write-Host "######### Secrets #########"
Write-Host "    SAVE THESE IN A SECURE LOCATION     " 