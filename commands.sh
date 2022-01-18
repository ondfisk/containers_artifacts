az login --tenant msftopenhack7126ops.onmicrosoft.com

SQL_PASSWORD=$(uuid)
NETWORK=team3
SQL_SERVER=sql
CONTAINER_REGISTRY=registryxgn2768

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

# Run data load container
docker run --network $NETWORK -e SQLFQDN=$SQL_SERVER -e SQLUSER=sa -e SQLPASS=$SQL_PASSWORD -e SQLDB=mydrivingDB $CONTAINER_REGISTRY.azurecr.io/dataload:1.0

# Build POI container
cd src/poi
docker build -t "tripinsights/poi:1.0" .

# Run local POI container
docker run -d -p 8080:80 --name poi --network $NETWORK -e "SQL_USER=sa" -e "SQL_PASSWORD=$SQL_PASSWORD" -e "SQL_SERVER=$SQL_SERVER" -e "ASPNETCORE_ENVIRONMENT=Local" tripinsights/poi:1.0
