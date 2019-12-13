
$Hostname="EWP000923.prod.telenet.be"
# Remove sessions if one is left open
Get-PSSession | Remove-PSSession
# create new session
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$Hostname/PowerShell/ -Authentication Kerberos
# import session, this should import commands from exchange server
Import-PsSession $Session -AllowClobber

#do some stuf


# Cleanup session
Get-PSSession | Remove-PSSession

############################################################################################################################################
$mail = "D_BP.and.CE.Incident.Mgtm.Old@telenetgroup.be"
$group = "CN=(D) BP and CE Incident Mgtm (Old),OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be"
$mo = Get-ADGroup -identity $group -properties "memberof"

foreach ($m in $mo.memberof){
    Remove-ADGroupMember -identity $m -members $group                   -WhatIf     # remove $group from the groups he is nested in
}
Set-ADGroup -Identity $group -GroupScope 2                              -WhatIf     # make $group universal
Enable-DistributionGroup -Identity $group -PrimarySmtpAddress $mail     -WhatIf     # make $group mail available
Set-ADGroup -Identity $group -GroupScope 1                              -WhatIf     # make $group global
foreach ($m in $mo.memberof){
    add-ADGroupMember -identity $m -members $group                      -WhatIf     # add the nesting back to $group
}

############################################################################################################################################
$group = "CN=(F) BP and CE Incident Mgtm (old),OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be"
$email = "D_BP.and.CE.Incident.Mgtm.Old@telenetgroup.be"
$x500 = "x500:/o=Telenet2003/ou=First Administrative Group/cn=Recipients/cn=(D)RSBCIncidentMgtmBillToCash"
$alias = "(D) BP and CE Incident Mgtm (Old)"
Set-DistributionGroup -identity $group  -emailaddresses @{Add=$email}
Set-DistributionGroup -identity $group  -emailaddresses @{Add=$x500}
# revert action
# Set-DistributionGroup -identity $group -emailaddresses @{Remove=$email}
############################################################################################################################################
$group = "CN=(F) BP and CE Incident Mgtm (old),OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be"
$email = "F_BP.and.CE.Incident.Mgtm.Old@telenetgroup.be"
Set-DistributionGroup -identity $group -PrimarySmtpAddress $email 
Set-DistributionGroup -identity $group  -emailaddresses @{Remove="system.collections.hashtable@telenetgroup.be"}
############################################################################################################################################
$old_group = "CN=(D) TB Project Delivery CPM,OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be"
$group = "CN=(F) TB Project Delivery CPM,OU=Groups Functional,OU=PROD,DC=prod,DC=telenet,DC=be"
$email = "TB.CPM@telenetgroup.be"
Set-DistributionGroup -identity $old_group  -emailaddresses @{Remove=$email}
Set-DistributionGroup -identity $group      -emailaddresses @{Add=$email}
############################################################################################################################################
$OU_APP = "OU=Groups TIM Application Entitlements,OU=PROD,DC=prod,DC=telenet,DC=be"
$OU_DEP = "OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be"
$Group_Name = read-host "Enter Group Name"