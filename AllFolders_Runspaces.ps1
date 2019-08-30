# processing pools
$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()

# script to run in runspace
$scriptblock = {
    param(
        $folder,
        $startSlash,
        $location,
        $error_output_path 
    )
    # main function, does not create other runspaces
    # this function loops through all the folders of a folder and writes each acl access rule to a file
    function get-Folders{
        param(
            $path,
            $startSlash,
            $location,
            $error_output_path 
        )
        $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
        try{
            foreach($folder in $listofFolders){
                $FolderLVL = ($folder.ToCharArray() | ? { $_ -eq "\" } | measure ).count - $startSlash
                # gets the ACL
                try{
                    $ACL = get-acl $folder
                }catch{
                    # writes error to folder
                    $ErrorMessage = $_.Exception.Message
                    write-output "$($ErrorMessage)"
    
                    $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
                    Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
                    continue
                }
                #loop through all $ACL of folder
                $sw = New-Object System.IO.StreamWriter "$($location)\FolderPerm.csv",$true
                foreach($ACE in $ACL.Access){
                    # write all access rules of a folder to file
                    $sw.WriteLine("$($folder);$($ACE.IdentityReference);$($FolderLVL);$($ACE.IsInherited)")
                }
                $sw.Close()
                # Recursive go through folders
                get-Folders $folder $startSlash $location $error_output_path 
            }
        }catch{
            # write error to file
            $ErrorMessage = $_.Exception.Message
            write-output "$($ErrorMessage)"
    
            $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
            Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
            continue
        }
    }
    # Start the function
    get-Folders $folder $startSlash $location $error_output_path 
}
# makes runspace
function get-runspace{
    param(
        $scriptblock,
        $folder,
        $startSlash,
        $location,
        $error_output_path 
    )
    
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)

    $null = $runspace.AddArgument($folder)
    $null = $runspace.AddArgument($startSlash)
    $null = $runspace.AddArgument($location)
    $null = $runspace.AddArgument($error_output_path)

    $runspace.RunspacePool = $pool
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }

    while ($runspaces.Status -ne $null){
        $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
        foreach ($runspace in $completed){
            $runspace.Pipe.EndInvoke($runspace.Status)
            $runspace.Status = $null
        }
    }
}

# loop to 3th level folder
# for each 3th level folder start a runspace
function get-Folders{
    param(
        $path,
        $startSlash,
        $startparallel,
        $location,
        $error_output_path 
    )
    $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
    try{
        foreach($folder in $listofFolders){
            $FolderLVL = ($folder.ToCharArray() | ? { $_ -eq "\" } | measure ).count - $startSlash
            # if (third level)$startparallel folder then start a paralel process
            if($FolderLVL -eq $startparallel){
                Write-Warning "Start runspace: $($FolderLVL) - $($folder)"
                get-runspace $scriptblock $folder $startSlash $location $error_output_path 
            }
            # if we started a paralel for it then just skip over it
            if($FolderLVL -gt $startparallel){
                continue
            }
            # get the ACL of the folder
            try{
                $ACL = get-acl $folder
            }catch{
                # write error to file
                $ErrorMessage = $_.Exception.Message
                write-output "$($ErrorMessage)"

                $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
                Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
                continue
            }
            # loop to the access rules in the ACL
            # write the access rules to file
            $sw = New-Object System.IO.StreamWriter "$($location)\FolderPerm.csv",$true
            foreach($ACE in $ACL.Access){
                $sw.WriteLine("$($folder);$($ACE.IdentityReference);$($FolderLVL);$($ACE.IsInherited)")
            }
            $sw.Close()
            # Recursive go throught the folders
            get-Folders $folder $startSlash $startparallel $location $error_output_path 
        }
    }catch{
        $ErrorMessage = $_.Exception.Message
        write-output "$($ErrorMessage)"

        $date_now = get-date -Format "yyyy-MM-dd hh:mm:ss"
        Add-Content $error_output_path "$($date_now);$($folder);$($ErrorMessage)"
        continue
    }
}
# input parameters
$folder = "C:\Users\ycreyf\Desktop\Test\"
$startSlash = ($folder.ToCharArray() | ? { $_ -eq "\" } | measure ).count -1
$startparallel = 3
$location = 'C:\Users\ycreyf\OneDrive - Telenet\Working Folders\Scripts&Exports\PowerShell'

$date = Get-Date -Format "yyyy-MM-dd"
$error_output_path = "$($location)\$($date)_Errors.csv"
# error output file; adding headers
if(-not (Test-Path $error_output_path -PathType Leaf)){
    write-warning "Path does not exist: $($error_output_path)"
    Add-Content $error_output_path "Date;Folder;Error"
}

# main function;
get-Folders $folder $startSlash $startparallel $location $error_output_path

Add-Content "$($location)\Last_scan_all_Folders.csv" $date
# clean up
$pool.Close()
$pool.Dispose()
