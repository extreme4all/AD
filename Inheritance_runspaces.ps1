$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()

$scriptblock = {
    param (
        $start,
        $startSlash,
        $location,
        $scriptblock,
        $pool
    )
    
    $scriptblock = ([scriptblock]::Create($scriptblock))
    function get-runspace{
        param(
            $start,
            $startSlash,
            $location,
            $scriptblock,
            $pool
        )
        
        $runspace = [PowerShell]::Create()
        
        $null = $runspace.AddScript($scriptblock)

        $null = $runspace.AddArgument($start)
        $null = $runspace.AddArgument($startSlash)
        $null = $runspace.AddArgument($location)
        $null = $runspace.AddArgument($scriptblock)
        $null = $runspace.AddArgument($pool)
        
        $runspace.RunspacePool = $pool
        $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
        
        # retrieve results
        while ($runspaces.Status -ne $null){
            $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
            foreach ($runspace in $completed){
                $results = $runspace.Pipe.EndInvoke($runspace.Status)
                # write output to get the data in the main loop
                # $date = Get-Date -Format "yyyy-MM-dd"
                # Start-Transcript -Path "$($location)\$($date)_INHjobs.log" -Append
                $date = Get-Date -Format "yyyy-MM-dd"
                Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value $results
                foreach($result in $results){Write-Output $result}
                # Stop-Transcript
                $runspace.Status = $null
            }
        }
    }
    # this function removes access rules from ACL
    function remove-ACE($ACL,$ACE,$folder){
        try{
            write-output "Removing: ($($ACE.IdentityReference))"
            write-output "From: ($($folder))"
            # $ACL.RemoveAccessRule($ACE)
            # $ACL | Set-Acl $folder
        }catch{
            $ErrorMessage = $_.Exception.Message
            write-output "$($ErrorMessage)"
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # corrects inheritanceFlags that are setup incorrect
    function get-inheritance($ACL,$ACE,$folder){
        if($ACE.InheritanceFlags -ne "ContainerInherit, ObjectInherit" -or $ACE.PropagationFlags -ne 'None'){
            write-output "no inheritance: $($folder) $($ACE.IdentityReference)"
            $date = Get-Date -Format "yyyy-MM-dd"
            Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value $folder
            # $permission = $ACE.IdentityReference, $ACE.FileSystemRights,'ContainerInherit,ObjectInherit', 'None','Allow'
            # $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
            # $ACL.SetAccessRule($rule)
            # $ACL | Set-Acl $folder
             
        }
    }
    function get-test($path){
        $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
        try {
            foreach($folder in $listofFolders){
                $FolderLVL = ($folder.ToCharArray() | ? { $_ -eq "\" } | measure ).count - $startSlash
                try{
                    $ACL = get-acl $folder
                }catch{
                    $ErrorMessage = $_.Exception.Message
                    write-output "$($ErrorMessage)"
                    $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
                    Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
                    continue
                }
                
                foreach ($ACE in $ACL.Access){
                    if($FolderLVL -eq 3){
                        $IDRef = $ACE.IdentityReference
                        if	($IDRef -like 'PROD\FSG*' -or $IDRef -like 'S-*' -or $IDRef -eq 'PROD\FileServerSecurityAdmins' -or $IDRef -eq 'PROD\Domain Admins') { 
                            # okay continue
                            # check if inheritance is on and turn it on
                            get-inheritance $ACL $ACE $folder
                            continue
                        }
                        ### for testing
                        # i dont want to remove myself from the file system
                        if	($IDRef -eq 'PROD\ycreyf' -or $IDRef -eq 'NT AUTHORITY\SYSTEM' -or $IDRef -eq 'BUILTIN\Administrators') { 
                            get-inheritance $ACL $ACE $folder
                            continue
                        }
                        # this ACE does not fit the criteria to be a 3th lvl group
                        # must be removed
                        remove-ACE $ACL $ACE $folder
                    }
                    if($FolderLVL -gt 3){
                        
                        if(-not $ACE.IsInherited){
                            # this ACE is not inherited, must be removed
                            remove-ACE $ACL $ACE $folder
                        }
                    }
                }

                if($FolderLVL -eq 3){
                    # write-output $folder
                    # Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value $folder
                    get-runspace $folder $startSlash $location $scriptblock $pool  
                }else {
                    get-test($folder)
                }
            }
        } catch {
            $ErrorMessage = $_.Exception.Message
            write-output "$($ErrorMessage)"
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }

    $date = Get-Date -Format "yyyy-MM-dd"
    $error_output_path = "$($location)\$($date)_Errors.csv"
    
    # error output file
    if(-not (Test-Path $error_output_path -PathType Leaf)){
        write-output "Create error folder: $($error_output_path)"
        Add-Content $error_output_path "Date;Folder;Error"
    }
    get-test($start)
}

# makes ar runspace
function get-runspace{
    param(
        $start,
        $startSlash,
        $location,
        $scriptblock,
        $pool
    )
    
    $runspace = [PowerShell]::Create()

    $null = $runspace.AddScript($scriptblock)

    $null = $runspace.AddArgument($start)
    $null = $runspace.AddArgument($startSlash)
    $null = $runspace.AddArgument($location)
    $null = $runspace.AddArgument($scriptblock)
    $null = $runspace.AddArgument($pool)
    
    $runspace.RunspacePool = $pool
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
    
    # retrieve results
    while ($runspaces.Status -ne $null){
        $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
        foreach ($runspace in $completed){
            $results = $runspace.Pipe.EndInvoke($runspace.Status)
            # write output to get the data in the main loop
            # foreach($result in $results){Write-Output $result}
            $date = Get-Date -Format "yyyy-MM-dd"
            Add-Content -Path "$($location)\$($date)_INHjobs.log" -Value $results
            $runspace.Status = $null
        }
    }
}

$Stopwatch = [system.diagnostics.stopwatch]::StartNew()

$start = "C:\Users\ycreyf\Desktop\Test\"
$startSlash = ($start.ToCharArray() | ? { $_ -eq "\" } | measure ).count -1
$location = 'C:\Users\ycreyf\OneDrive - Telenet\Working Folders\Scripts&Exports\PowerShell' # get-location

get-runspace $start $startSlash $location $scriptblock $pool

$date = Get-Date -Format "yyyy-MM-dd"
Add-Content "$($location)\Last_scan_all_Folders.csv" $date

$pool.Close()
$pool.Dispose()

$Stopwatch.Stop()
$Stopwatch.Elapsed
