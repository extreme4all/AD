
$Groups = 'CN=(D) HR Non Active,OU=Groups Department,OU=PROD,DC=prod,DC=telenet,DC=be'
foreach($Group in $Groups){
    $AD_Group = Get-ADGroup -Identity $Group
    $Scope=1
    switch($Scope){
        0 {$ScopeName = 'DomainLocal'}
        1 {$ScopeName = 'Global'}
        2 {$ScopeName = 'Universal'}
    }

    if($AD_Group.GroupScope -ne $Scope){
        write-warning "Changing for: [$($Group)] [$($AD_Group.GroupScope)] to [$($ScopeName)]"
        Set-ADGroup -Identity $Group -GroupScope $Scope
    }else{
        write-host "[$($Group)] is [$($AD_Group.GroupScope)]"
    }
}
