
$script = 
{param($start,$startSlash,$location,$script,$maxConcurrentJobs)
    $script = ([scriptblock]::Create($script))

    # this function removes access rules from ACL
    function remove-ACE($ACL,$ACE,$folder){
        try{
            write-warning "Removing: ($($ACE.IdentityReference))"
            write-warning "From: ($($folder))"
            # $ACL.RemoveAccessRule($ACE)
            # $ACL | Set-Acl $folder
        }catch{
            $ErrorMessage = $_.Exception.Message
            Write-Warning "$($ErrorMessage)"
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # corrects inheritanceFlags that are setup incorrect
    function get-inheritance($ACL,$ACE,$folder){
        if($ACE.InheritanceFlags -ne "ContainerInherit, ObjectInherit" -or $ACE.PropagationFlags -ne 'None'){
            write-warning "no inheritance in $($folder) $($ACE.IdentityReference)"
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
                    Write-Warning "$($ErrorMessage)"
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
                    $check = $false
                    while ($check -eq $false){
                        if((get-job -State 'Running').Count -lt $maxConcurrentJobs){
                            $job = Start-Job -Name "INH:$($folder)" -ScriptBlock $script -ArgumentList $folder,$startSlash,$location,$script,$maxConcurrentJobs
                            Write-host "Running job: INH:$($folder)"

                            $jobs = Get-Job -State "Running"
                            While (Get-Job -State "Running") {
                                foreach($j in $jobs){
                                    Receive-Job -Name $j.Name
                                }
                            }
                            
                            $check = $true
                        }
                    }
                }else {
                    get-test($folder)
                }
            }
        } catch {
            $ErrorMessage = $_.Exception.Message
            Write-Warning "$($ErrorMessage)"
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    $date = Get-Date -Format "yyyy-MM-dd"
    $error_output_path = "$($location)\$($date)_Errors.csv"
    # error output file
    if(-not (Test-Path $error_output_path -PathType Leaf)){
        write-warning "Path does not exist: $($error_output_path)"
        Add-Content $error_output_path "Date;Folder;Error"
    }
    get-test($start)
}


$start = "C:\Users\ycreyf\Desktop\Test\"
$startSlash = ($start.ToCharArray() | ? { $_ -eq "\" } | measure ).count -1
$location = 'C:\Users\ycreyf\OneDrive - Telenet\Working Folders\Scripts&Exports\PowerShell' # get-location
$maxConcurrentJobs = 4
$job_name = "INH:Job"

$job = Start-Job -Name $job_name -ScriptBlock $script -ArgumentList $start,$startSlash,$location,$script,$maxConcurrentJobs

Start-Transcript -Path "$($location)\INHjobs.log" -Append
Write-Warning "Main job: $($job_name)"
While (Get-Job -State "Running") {
    cls
    Receive-Job -Name $job_name 
    Start-Sleep 1
}
Receive-Job -Name $job_name 

Stop-Transcript

write-host "Jobs completed"
Remove-Job -Name "INH:Job"