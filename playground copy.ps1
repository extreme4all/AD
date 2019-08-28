$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()
 
$scriptblock = {
    Param (
        [string]$server,
        [int]$count,
        [string]$scriptblock,
        $pool,
        $go
    )
    $scriptblock = ([scriptblock]::Create($scriptblock))
    # Pretend I connected to a server here and gathered some info
    Write-Output "Type: $server Loop: $count isFirst:$go"
    if($go -eq 1){
        1..5 | ForEach-Object {
            $go = 0
            $runspace = [PowerShell]::Create()
            $null = $runspace.AddScript($scriptblock)
            $null = $runspace.AddArgument("Nest")
            $null = $runspace.AddArgument($count)
            $null = $runspace.AddArgument($scriptblock)
            $null = $runspace.AddArgument($pool)
            $null = $runspace.AddArgument($go)
            $runspace.RunspacePool = $pool
            $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
        }
    }
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
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)
    $null = $runspace.AddArgument("Original")
    $null = $runspace.AddArgument(++$i)
    $null = $runspace.AddArgument($scriptblock)
    $null = $runspace.AddArgument($pool)
    $null = $runspace.AddArgument($go)
    $runspace.RunspacePool = $pool
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
    
}
 
while ($runspaces.Status -ne $null)
{
    $completed = $runspaces | Where-Object { $_.Status.IsCompleted -eq $true }
    foreach ($runspace in $completed)
    {
        $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Status = $null
    }
}
$pool.Close()
$pool.Dispose()
