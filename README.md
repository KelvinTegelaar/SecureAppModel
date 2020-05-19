# Secure Application Model for PowerShell
See https://www.cyberdrain.com/connect-to-exchange-online-automated-when-mfa-is-enabled-using-the-secureapp-model/ for more information.

Please note that you should NOT run this script in the PowerShell ISE as it will not work. Also note that when running the script with an MFA whitelist via the portal, the script fails. You must remove this whitelisting beforehand.

The following script creates a new application, and connects to all resources. At the end you will receive several private keys. Store these in a secure location for future usage such as a Azure Keyvault or IT-Glue. With these keys you can connect to all your delegated resources without MFA. 
