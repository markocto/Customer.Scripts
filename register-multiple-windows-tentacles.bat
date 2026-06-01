# ============================================================
# Octopus Deploy - Register Multiple Windows Tentacle Targets
# ============================================================

# --- Shared Configuration ---
$TentacleExe  = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
$OctopusServer = "http://octopus-admin.reef.local"
$ApiKey        = "API-XXXXXXXYYYYYYYYYYZZZZZZ"
$Space         = "Default"
$ServerCommsPort = "10943"
$AppBasePath   = "C:\Octopus\Applications"
$ListenPort    = "10933"
$ConfigBasePath = "C:\Octopus"

# --- Target Definitions ---
# Each hashtable defines one Tentacle instance to register.
# Required keys : InstanceName, Environment, Role
# Optional keys : Policy (defaults to "Default Machine Policy")
$Targets = @(
    @{
        InstanceName = "Tentacle-Web-01"
        Environment  = "Administration"
        Role         = "web-server"
        Policy       = "Default Machine Policy"
    },
    @{
        InstanceName = "Tentacle-DB-01"
        Environment  = "Production"
        Role         = "database-server"
        Policy       = "High-Security Machine Policy"
    },
    @{
        InstanceName = "Tentacle-App-01"
        Environment  = "Staging"
        Role         = "app-server"
        # Policy omitted — will fall back to default below
    }
)

# ============================================================

foreach ($Target in $Targets) {
    $InstanceName = $Target.InstanceName
    $Environment  = $Target.Environment
    $Role         = $Target.Role
    $Policy       = if ($Target.Policy) { $Target.Policy } else { "Default Machine Policy" }
    $ConfigFile   = "$ConfigBasePath\$InstanceName.config"

    Write-Host "`n=============================="
    Write-Host " Registering: $InstanceName"
    Write-Host "==============================`n"

    # 1. Create instance
    & $TentacleExe create-instance `
        --instance  $InstanceName `
        --config    $ConfigFile

    # 2. Generate certificate (only if one doesn't already exist)
    & $TentacleExe new-certificate `
        --instance  $InstanceName `
        --if-blank

    # 3. Reset trust
    & $TentacleExe configure `
        --instance  $InstanceName `
        --reset-trust

    # 4. Configure app path, port, and polling mode
    & $TentacleExe configure `
        --instance  $InstanceName `
        --app       $AppBasePath `
        --port      $ListenPort `
        --noListen  "True"

    # 5. Configure polling proxy (disabled)
    & $TentacleExe polling-proxy `
        --instance      $InstanceName `
        --proxyEnable   "False" `
        --proxyUsername "" `
        --proxyPassword "" `
        --proxyHost     "" `
        --proxyPort     ""

    # 6. Register with Octopus Server
    & $TentacleExe register-with `
        --instance          $InstanceName `
        --server            $OctopusServer `
        --name              $InstanceName `
        --comms-style       "TentacleActive" `
        --server-comms-port $ServerCommsPort `
        --apiKey            $ApiKey `
        --space             $Space `
        --environment       $Environment `
        --role              $Role `
        --policy            $Policy

    # 7. Install and start the service
    & $TentacleExe service `
        --instance  $InstanceName `
        --install `
        --stop `
        --start

    Write-Host "`n[OK] $InstanceName registered successfully."
}

Write-Host "`n=============================="
Write-Host " All targets registered."
Write-Host "==============================`n"