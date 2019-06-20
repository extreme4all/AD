

###
# Each folder until the 3th lvl folder should have Permissions (Groups)
# If the domain admin is not part of the permissions then we want to report that
# if a folder that is not 1-3th lvl has Permissions we want to report that
# however we are not interested in n-lvl folders that have inherited permissions
###

$location = Get-Location
$location = "$location\"
$Global:IDRefs_old =""
# Save file to current location with headers
Add-Content $location"Folders.csv" "Path;Permission;FolderLVL"
function data-to-csv ($Path,$Permission,$FolderLVL){
    $obj = [PSCustomObject]@{
        Path = $Path
        Permission = $Permission
        FolderLVL = $FolderLVL
    }
    # export to csv => delimiter with text qualifier 
    $obj | export-Csv -Path "$($location)Folders.csv" -Delimiter ";" -Append
}
function get-test($path){
    $listofFolders = [System.IO.Directory]::EnumerateDirectories($path)
    try {
        foreach($folder in $listofFolders){
            $IDRefs = ""
            # depth of current folder \\PROD451\PRD\DEP\ = LV 0 folder
            $FolderLVL = ($folder.ToCharArray() | ? { $_ -eq "\" } | measure ).count - $startSlash
            
            if ($FolderLVL -gt 6){
                # write-warning "To long: LVL: $($FolderLVL) Folder: $($folder) "
                continue
            }
            try{
                $IDRefs = (get-acl ($folder)).access.IdentityReference
            }catch{
                # documenting the folder that we have no rights to (domain admin is removed)
                # write-warning "No Rights: LVL: $($FolderLVL) Folder: $($folder)"
                data-to-csv -Path $folder -Permission "No Rights" -FolderLVL $FolderLVL
                continue
            }
            # if permission is different from last permission
            # then we dont want to write it to csv
            # 1st and 2nd can be inherited so we go through until 4th lvl, we support security until 3th lvl
            if($Match = @(Compare-Object $Global:IDRefs_old $IDRefs).Length -eq 0 -and $FolderLVL -gt 4){
                # write-warning "Inherited: LVL: $($FolderLVL) Folder: $($folder)"
                Continue
            }

            foreach ($IDRef in $IDRefs){
                if	($IDRef -like 'PROD\*') { 
                    data-to-csv -Path $folder -Permission $IDRef -FolderLVL $FolderLVL
                }
            }
            $Global:IDRefs_old = $IDRefs
            get-test($folder)
        }
    } catch {
        Write-Warning "catch: $($folder)"
        continue
    }
}
############change this############
$start = "\\PROD451\PRD\DEP\"
###################################
$startSlash = ($start.ToCharArray() | ? { $_ -eq "\" } | measure ).count -1
get-test($start)
