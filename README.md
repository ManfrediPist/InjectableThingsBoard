# InjectableThingsBoard
An injectable version of containerized ThingsBoard 2.4.0

The idea of this project is to be able restore a backup of Thingsboard in a easy and fashion way. 
In particular by exporting an existant dashboard you can destroy your container (and volume) and be able to restore the whole environment in a programmatic way (more or less).

To do so, some steps are required:

1) Create a binding file called "bindings" that stores relationship between assets and devices in the following format

```
AssetA_DeviceA
AssetA_DeviceB
AssetB_DeviceC 
...
```

2) Export your dashboard as json and rename it to "ASSETNAME.json" where ASSETNAME is the name of the asset it refers to (AssetA.json for example)

3) Open your dashboard.json and edit the json value referring to rootEntity Id inside entityAliases object and set it to "TO_REPLACE"

```
"entityAliases": {
      "6e79d550-6b2c-8b4c-0caf-b964feea9d43": {
        "id": "6e79d550-6b2c-8b4c-0caf-b964feea9d43",
        "alias": "Sensors",
        "filter": {
          "type": "deviceSearchQuery",
          "resolveMultiple": true,
          "rootStateEntity": false,
          "stateEntityParamName": null,
          "defaultStateEntity": null,
          "rootEntity": {
            "entityType": "ASSET",
            "id": "TO_REPLACE"                <---------- this was previously an id, you need to rename it as shown
          },
          "direction": "FROM",
          "maxLevel": 1,
          "relationType": "Contains",
          "deviceTypes": [
            "sensor"
          ]
        }
      }
    },
    ...
```
The environment setup is pretty straightforward:

1) compile the docker image inside Build folder by running the following command:

$ docker build -t thingsboard_dload ./Build/

(P.S you can choose whatever image tag name you like, just remeber to also change it on docker-compose accordingly)

2) Put the previously configured dashboards and "bindings" file into a folder called "tb_dashboards" 

3) Start the container

$ docker-compose up 
