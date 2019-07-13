#!/bin/bash

#Manfredi Pistone  <manfredi.pistone@gmail.com>

if [[ -z "$TB_URL" ]]; then
    echo "Setting env TB_URL to default..."
    export TB_URL=localhost
fi

if [[ -z "$TB_PORT" ]]; then
    echo "Setting env TB_PORT to default..."
    export TB_PORT=9090
fi

if [[ -z "$DASHBOARDS_PATH" ]]; then
    echo "Setting env DASHBOARDS_PATH to default..."
    export DASHBOARDS_PATH=/opt/dashboards
fi

if [[ -f "$DASHBOARDS_PATH/bindings" ]]
then
    bindings_file="$DASHBOARDS_PATH/bindings"
else
    echo "Missing binding files"
    exit 1
fi

while [[ "$(curl --insecure -s -o /dev/null -w ''%{http_code}'' http://$TB_URL:$TB_PORT)" != "200" ]]
do
  echo "Waiting for ThingsBoard WebUI to load..."
  sleep 5;
done

echo "ThingsBoard WebUI loaded successfully!"

AUTH_KEY=$(curl -sS --url "http://$TB_URL:$TB_PORT/api/auth/login" \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--data '{"username":"tenant@thingsboard.org", "password":"tenant"}' | cut -d '"' -f 4)

echo "Obtained AuthKey: $AUTH_KEY"

last_asset_id=""
while IFS= read -r line
do
  asset=$(echo $line | cut -d "_" -f 1)
  device=$(echo $line | cut -d "_" -f 2)

  echo "Creating device: $device"
  device_id=$(curl -sS --url "http://$TB_URL:$TB_PORT/api/device" \
  --header 'Accept: application/json, text/plain, */*' \
  --header 'Content-Type: application/json;charset=utf-8' \
  --header "X-Authorization: Bearer $AUTH_KEY" \
  --compressed \
  --data '{"name":"'$device'","type":"sensor"}'| cut -d '"' -f 10 )
  echo "Current device_id: $device_id"

  credentials_req_id=$(curl -sS --url "http://$TB_URL:$TB_PORT/api/device/$device_id/credentials" \
  --header 'Accept: application/json, text/plain, */*' \
  --header "X-Authorization: Bearer $AUTH_KEY" | cut -d '"' -f 6 )
  echo "Current credentals request id: $credentials_req_id"

  echo "Setting up access token for device $device"
  #you may want to change the acess_token
  access_token=$device
  curl -sS --url "http://$TB_URL:$TB_PORT/api/device/credentials" \
  --header 'Accept: application/json, text/plain, */*' \
  --header 'Content-Type: application/json;charset=utf-8' \
  --header "X-Authorization: Bearer $AUTH_KEY" \
  --compressed \
  --data '{"id":{"id":"'$credentials_req_id'"},"createdTime":1557835681381,"deviceId":{"entityType":"DEVICE","id":"'$device_id'"},"credentialsType":"ACCESS_TOKEN","credentialsId":"'$access_token'","credentialsValue":null}' > /dev/null
  echo "Access token setted up"

  assets_list=$(curl -sS --url "http://$TB_URL:$TB_PORT/api/tenant/assets?limit=30&textSearch=" \
  --header 'Accept: application/json, text/plain, */*' \
  --header 'Content-Type: application/json;charset=utf-8' \
  --header "X-Authorization: Bearer $AUTH_KEY" | python -m json.tool)

  status_code=$(echo $assets_list | grep $asset | wc -l)
  if [[ $status_code -ne 0 ]]
  then
      echo "$asset does already exist!"
  else
      echo "Creating asset: $asset"
      last_asset_id=$(curl -sS --url "http://$TB_URL:$TB_PORT/api/asset" \
      --header 'Accept: application/json, text/plain, */*' \
      --header 'Content-Type: application/json;charset=utf-8' \
      --header "X-Authorization: Bearer $AUTH_KEY" \
      --compressed \
      --data '{"name":"'$asset'","type":"Asset"}'| cut -d '"' -f 10 )
  fi

  echo "Current asset_id: $last_asset_id"

  echo "Creating relationship..."
  echo "$device is part of $asset"
  echo "$device_id must be in relation to $last_asset_id"

  curl -sS --url "http://$TB_URL:$TB_PORT/api/relation" \
  --header 'Accept: application/json, text/plain, */*' \
  --header 'Content-Type: application/json;charset=utf-8' \
  --header "X-Authorization: Bearer $AUTH_KEY" \
  --compressed \
  --data '{"from":{"id":"'$last_asset_id'","entityType":"ASSET"},"type":"Contains","to":{"entityType":"DEVICE","id":"'$device_id'"},"additionalInfo":null}'
  echo "Relationship created successfully"


  dashboard="$DASHBOARDS_PATH/$asset.json"
  if [[ $status_code -ne 0 ]]
  then
      echo "$dashboard has already been imported!"
  else
      echo "Looking for dashboard to inject: $dashboard"

      if test -f $dashboard;
      then
          echo "Dashboard found: $dashboard"
          sed "s/TO_REPLACE/$last_asset_id/g" < $dashboard > $dashboard.new

          curl -sS --url "http://$TB_URL:$TB_PORT/api/dashboard" \
          --header 'Content-Type: application/json' \
          --header 'Accept: application/json' \
          --header "X-Authorization: Bearer $AUTH_KEY" \
          --data "@$dashboard.new" > /dev/null

          echo "Dashboard injected into ThingsBoard"
          curl -sS --url "http://$TB_URL:$TB_PORT/api/devices" \
          --header 'Accept: application/json, text/plain, */*' \
          --header 'Content-Type: application/json;charset=utf-8' \
          --header "X-Authorization: Bearer $AUTH_KEY" \
          --compressed \
          --data '{"parameters":{"rootId":"'$last_asset_id'","rootType":"ASSET","direction":"FROM","maxLevel":1},"relationType":"Contains","deviceTypes":["sensor"]}' > /dev/null
          echo "Entities setted up for dashboard $dashboard"

          rm $dashboard.new
      else
        echo "Missing file: $dashboard"
      fi
  fi

done < $bindings_file
