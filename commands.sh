az login --tenant msftopenhack7126ops.onmicrosoft.com

SQL_PASSWORD=$(uuid)
NETWORK=team3
SQL_SERVER=sql
CONTAINER_REGISTRY=registryxgn2768
ACR=$CONTAINER_REGISTRY.azurecr.io


# Login to ACR
az acr login -n $CONTAINER_REGISTRY

# Create network
docker network create $NETWORK

# Run SQL Server
docker run --network $NETWORK -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$SQL_PASSWORD" -p 1433:1433 --name sql -h $SQL_SERVER -d mcr.microsoft.com/mssql/server:2017-latest

# Create mydrivingDB database
docker exec -it sql "bash"
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA
CREATE DATABASE mydrivingDB
GO
exit
exit

# Run dataload container
docker run --network $NETWORK -e SQLFQDN=$SQL_SERVER -e SQLUSER=sa -e SQLPASS=$SQL_PASSWORD -e SQLDB=mydrivingDB $CONTAINER_REGISTRY.azurecr.io/dataload:1.0

# Build poi container
cd src/poi
docker build -t "tripinsights/poi:1.0" .

# Run local poi container
docker run -d -p 8080:80 --name poi --network $NETWORK -e "SQL_USER=sa" -e "SQL_PASSWORD=$SQL_PASSWORD" -e "SQL_SERVER=$SQL_SERVER" -e "ASPNETCORE_ENVIRONMENT=Local" tripinsights/poi:1.0

# Test poi
curl -i -X GET 'http://localhost:8080/api/trips'

# Build poi in ACR
cd ../../src/poi
az acr build -r $ACR -t $ACR/tripinsights/poi:1.0 .

# Build trips in ACR
cd ../../src/trips
az acr build -r $ACR -t $ACR/tripinsights/trips:1.0 .

# Build tripviewer in ACR
cd ../../src/tripviewer
az acr build -r $ACR -t $ACR/tripinsights/tripviewer:1.0 .

# Build user-java in ACR
cd ../../src/user-java
az acr build -r $ACR -t $ACR/tripinsights/user-java:1.0 .

# Build userprofile in ACR
cd ../../src/userprofile
az acr build -r $ACR -t $ACR/tripinsight/userprofile:1.0 .

# Challenge 4

# Configure secrets for api namespace
kubectl create secret generic sqlconnection --namespace=api --from-literal=SQL_DBNAME=$SQL_DBNAME --from-literal=SQL_SERVER=$SQL_SERVER --from-literal=SQL_USER=$SQL_USER --from-literal=SQL_PASSWORD=$SQL_PASSWORD

AKS_ID=$(az aks show \
    --resource-group teamResources \
    --name aks \
    --query id -o tsv)

WEBDEV_ID=$(az ad group create --display-name webdev --mail-nickname webdev --query objectId -o tsv)
APIDEV_ID=$(az ad group create --display-name apidev --mail-nickname apidev --query objectId -o tsv)

az role assignment create \
  --assignee $WEBDEV_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID


# Set secrets in KV
KEYVAULT=team3-2342352345
sql-server SQL_SERVER

az keyvault secret set --vault-name $KEYVAULT -n sql-server --value sqlserverxgn2768.database.windows.net
az keyvault secret set --vault-name $KEYVAULT -n sql-user --value sqladminxGn2768
az keyvault secret set --vault-name $KEYVAULT -n sql-dbname --value mydrivingDB
az keyvault secret set --vault-name $KEYVAULT -n sql-password --value nB3ul0Ts6

export IDENTITY_NAME="application-identity"
az identity create --resource-group teamResources --name ${IDENTITY_NAME}
export IDENTITY_CLIENT_ID="$(az identity show -g teamResources -n ${IDENTITY_NAME} --query clientId -otsv)"
export IDENTITY_RESOURCE_ID="$(az identity show -g teamResources -n ${IDENTITY_NAME} --query id -otsv)"
export POD_IDENTITY_NAME="my-pod-identity"
export POD_IDENTITY_NAMESPACE="api"
az aks pod-identity add --resource-group teamResources --cluster-name aks --namespace ${POD_IDENTITY_NAMESPACE}  --name ${POD_IDENTITY_NAME} --identity-resource-id ${IDENTITY_RESOURCE_ID}