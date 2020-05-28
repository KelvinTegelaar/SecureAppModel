$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'ApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'Your-tenantID'
$RefreshToken = 'RefreshToken'
$ExchangeRefreshToken = 'ExchangeRefreshToken'
$UPN = "Exisiting-UPN-with-Partner-Permissions"

$token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716'-RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default'
$tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)

$SccSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.compliance.protection.outlook.com/powershell-liveid?BasicAuthToOAuthConversion=true&DelegatedOrg=$($customerId)" -Credential $credential -AllowRedirection -Authentication Basic
import-session $SccSession -disablenamechecking -allowclobber