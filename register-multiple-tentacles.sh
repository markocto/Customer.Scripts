#!/bin/bash

# --- Configuration ---
serverUrl="https://your-octopus-server"
apiKey="API-XXXXXXXXXXXX"
spaceName="Default"
serverCommsPort=10943
applicationPath="/home/octopus/Applications"

# Define each Tentacle as: "name|environment|role|policy"
tentacles=(
  "web-01|Production|web-server|Default Machine Policy"
  "web-02|Production|web-server|Default Machine Policy"
  "api-01|Staging|api-server|Custom Policy"
)

# --- Registration Loop ---
for tentacle in "${tentacles[@]}"; do
  IFS='|' read -r name environment role policy <<< "$tentacle"

  configFilePath="/etc/octopus/$name/tentacle-$name.config"

  echo "=========================================="
  echo "Registering Tentacle: $name"
  echo "  Environment : $environment"
  echo "  Role        : $role"
  echo "  Policy      : $policy"
  echo "  Config      : $configFilePath"
  echo "=========================================="

  /opt/octopus/tentacle/Tentacle create-instance \
    --instance "$name" \
    --config "$configFilePath"

  /opt/octopus/tentacle/Tentacle new-certificate \
    --instance "$name" \
    --if-blank

  /opt/octopus/tentacle/Tentacle configure \
    --instance "$name" \
    --noListen True \
    --reset-trust \
    --app "$applicationPath"

  /opt/octopus/tentacle/Tentacle register-with \
    --instance "$name" \
    --server "$serverUrl" \
    --apiKey "$apiKey" \
    --space "$spaceName" \
    --name "$name" \
    --env "$environment" \
    --role "$role" \
    --comms-style "TentacleActive" \
    --server-comms-port "$serverCommsPort" \
    --policy "$policy"

  /opt/octopus/tentacle/Tentacle service \
    --instance "$name" \
    --install \
    --start

  if [ $? -eq 0 ]; then
    echo "✓ $name registered and started successfully"
  else
    echo "✗ $name failed — check logs above"
    exit 1
  fi

done

echo ""
echo "All ${#tentacles[@]} Tentacle(s) registered successfully."