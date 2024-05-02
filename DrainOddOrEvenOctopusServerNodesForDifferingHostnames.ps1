# The original script is here:
# https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Administration/DrainOddOrEvenOctopusServerNodes.ps1

$octopusURL = "http://octopus-ha.reef.local"
$octopusAPIKey = "API-1QDDEVBYG35VVF3PODLK8XRTP1NQMPLQ"
$headers = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Set to $True to drain "even" numbered nodes
# Set to $False to drain "odd" numbered nodes
$DrainEvenNodes = $True

if ($octopusURL.EndsWith("/")) {
    $serverNodeUri = $OctopusUrl.Substring(0, $OctopusUrl.Length - 1);
}

# Get Octopus Server Nodes
$octopusServerNodesResponse = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/octopusservernodes/summary" -Headers $headers
$octopusServerNodes = $octopusServerNodesResponse.Nodes

for ($i = 0; $i -lt $octopusServerNodes.Length; $i++) {
    
    $octopusServerNode = $octopusServerNodes[$i]
    $nodeName = $octopusServerNode.Name
    
    # try to get node number from name
    [int]$nodeNumber = $null 
    $nameParts = $nodeName.Split('-')
    if ($nameParts.Length -gt 1) {
        $possibleNodeNumber = $nameParts[1]
        
        if ([int32]::TryParse($possibleNodeNumber, [ref]$nodeNumber )) {
            Write-Verbose "Parsed node number from $nodeName as: $nodeNumber" 
        }
        else {
            Write-Warning "Unable to parse node number from $nodeName, setting to index: $i" 
            $nodeNumber = $i
        }
    }
    else {
        Write-Warning "Unable to determine a possible node number from $nodeName, setting to index: $i" 
        $nodeNumber = $i
    }
    
    $nodeModuloResult = $nodeNumber % 2
    $ContinueDrainOperation = ($DrainEvenNodes -eq $True -and $nodeModuloResult -eq 0) -or ($DrainEvenNodes -eq $False -and $nodeModuloResult -eq 1)
    if ($ContinueDrainOperation) {
        
        if ($octopusServerNode.IsInMaintenanceMode -eq $True) {
            Write-Output "Skipping drain of node: $nodeName as its already in a draining/drained state"
            Continue;
        }

        Write-Output "Draining node: $nodeName"
        $body = @{
            Id                  = $octopusServerNode.Id
            Name                = $octopusServerNode.MaxConcurrentTasks
            MaxConcurrentTasks  = $octopusServerNode.MaxConcurrentTasks
            IsInMaintenanceMode = $true
        }

        # Convert body to JSON
        $body = $body | ConvertTo-Json -Depth 10
        $serverNodeUri = $OctopusUrl + $octopusServerNode.Links.Node;
        
        # Post update
        $updateServerNodeResponse = Invoke-RestMethod -Method Put -Uri $serverNodeUri -Body $body -Headers $headers 

        # This script can be extended to check the nodes have completed a drain operation by checking the nodes RunningTaskCount property is 0
    }
    else {
        Write-Output "Skipping drain of node: $nodeName as its not a valid candidate"
    }
}
