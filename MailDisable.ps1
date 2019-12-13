$Hostname="EWP000923.prod.telenet.be"
# Remove sessions if one is left open
Get-PSSession | Remove-PSSession
# create new session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$Hostname/PowerShell/ -Authentication Kerberos
$Session
# import session, this should import commands from exchange server
Import-PsSession $Session -AllowClobber

# disable all groups in the Groups Departement OU that have no extensionAttribute1
$Groups = Get-ADGroup -SearchBase "OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be" -Filter {extensionAttribute1 -NotLike "*"}
foreach ($Group in $Groups) {
    write-host "Disable-DistributionGroup: $($Group.Name)"
    Disable-DistributionGroup -identity "$Group" -confirm:$false
}

# Cleanup session
Get-PSSession | Remove-PSSession