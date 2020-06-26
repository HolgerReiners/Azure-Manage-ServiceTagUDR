# Azure-Manage-ServiceTagUDR

## purpose
Manage Azure Service Tags in Azure User-Defined Routes (UDR)

It can add for a specific Azure service tag the IP ranges from the JSON file into the UDR (ServiceTagUDR).
It can remove for a specific Azure service tag the IP route from the UDR (ServiceTagUDR).
every ServiceTagUDR be in the naming format

route name will be formated as: < prefix >-< cloud >-< serviceTag >-< serviceTagChangeNr >-< routeNumber >-< date of update >

## prerequisites
  - Authenticated management session to the Azure cloud environment
  - correct subscription is selected and active
  - Powershell Az commands are installed - https://docs.microsoft.com/en-us/powershell/azure/

## input
- cloudEnv [mandatory] - cloud environment information to use ['Public','USGov','China','Germany']
- serviceTag [mandatory] - ServiceTag to use for the operation, as defined in the Azure Service Tag JSON
- operation [mandatory] - management action of service tag IPs on the UDR [add or remove]
- resourceGroup [mandatory] - resource group name, where the route table exist
- routeTableName [mandatory] - route table to operate, must exist before. will not be created
- routePrefix [optional] - route prefix, default 'STUDR' (service tag user defined route)

## output
updated UDR in the Azure cloud environment

# additional information:
- Azure Docs - Service Tag: https://docs.microsoft.com/en-us/azure/virtual-network/service-tags-overview
- Azure Subscription limits: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits

Azure Service Tag Download URLs (2020 03)
- Public Cloud - https://www.microsoft.com/download/details.aspx?id=56519
- US Government - https://www.microsoft.com/download/details.aspx?id=57063
- China - https://www.microsoft.com/download/details.aspx?id=57062
- Germany - https://www.microsoft.com/download/details.aspx?id=57064