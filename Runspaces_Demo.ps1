$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()
 
$scriptblock = {
    Param (
        $server,
        $count,
        $go,
        $scriptblock
    )
    $scriptblock = ([scriptblock]::Create($scriptblock))
    # Pretend I connected to a server here and gathered some info
    Write-Output "Type: $server Loop: $count isFirst:$go"

    # makes ar runspace
    function get-runspace{
        param(
            $server,
            $count,
            $go
        )
        
        $runspace = [PowerShell]::Create()
        $null = $runspace.AddScript($scriptblock)
        $null = $runspace.AddArgument($server)
        $null = $runspace.AddArgument($count)
        $null = $runspace.AddArgument($go)
        $null = $runspace.AddArgument($scriptblock)
        $runspace.RunspacePool = $pool
        $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
        # retrieve results

        while ($runspaces.Status -ne $null){
            $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
            foreach ($runspace in $completed){
                $results = $runspace.Pipe.EndInvoke($runspace.Status)
                # write output to get the data in the main loop
                foreach($result in $results){Write-Output $result}
                $runspace.Status = $null
            }
        }
    }
    # launch nested runspaces
    if($go -eq 1){
        1..5 | ForEach-Object {
            $go = 0
            $count = ++$i
            get-runspace "Nested" $count $go
        }
    }
}
# makes ar runspace
function get-runspace{
    param(
        $server,
        $count,
        $go,
        $scriptblock
    )
    
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)
    $null = $runspace.AddArgument($server)
    $null = $runspace.AddArgument($count)
    $null = $runspace.AddArgument($go)
    $null = $runspace.AddArgument($scriptblock)
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

1..10 | ForEach-Object {
    $go = 1
    $count = ++$i
    get-runspace "Original" $count $go $scriptblock
    
}
$pool.Close()
$pool.Dispose()
