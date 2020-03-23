################################################################################################
# Manage-ServiceTagUDR.ps1
# 
# AUTHOR: Holger Reiners, Microsoft Deutschland GmbH
#         Christian Thönes, Microsoft Deutschland GmbH
# VERSION: 0.1
# DATE: 23.03.2020
#
# purpose:
#   manage Azure Service Tags in Azure User-Defined Routes (UDR)
#   it will add for a specific Azure service tag the IP ranges from the JSON file into the UDR (ServiceTagUDR).
#   every ServiceTagUDR be in the naming format
#       AStUdr-<ServiceTag>-<###>-<ChangeNr>-<date of update>
#
# prerequisites:
#   - Authenticated management session to the Azure cloud environment
#   - correct subscription is selected and active
#   - Powershell Az commands are installed - https://docs.microsoft.com/en-us/powershell/azure/
#
# input:
#   UDR - to update, must exist
#   activity - management action of Service Tag IPs on the UDR (add or update, delete)
#   ServiceTag - ServiceTag to use for the operation
#
# output:
#   - success or failue (true / false)
#   - updated UDR in the Azure cloud environment
#
# additional information:
#   Azure Docs - Service Tag: https://docs.microsoft.com/en-us/azure/virtual-network/service-tags-overview
#   Azure Subscription limits: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits
#
#   Azure Service Tag Download URLs (2020 03)
#    - Public Cloud - https://www.microsoft.com/download/details.aspx?id=56519
#    - US Government - https://www.microsoft.com/download/details.aspx?id=57063
#    - China - https://www.microsoft.com/download/details.aspx?id=57062
#    - Germany - https://www.microsoft.com/download/details.aspx?id=57064
#
# THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
# FITNESS FOR A PARTICULAR PURPOSE.
#
# This sample is not supported under any Microsoft standard support program or service. 
# The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
# implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose. The entire risk arising out of the use or performance
# of the sample and documentation remains with you. In no event shall Microsoft, its authors,
# or anyone else involved in the creation, production, or delivery of the script be liable for 
# any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of 
# the use of or inability to use the sample or documentation, even if Microsoft has been advised 
# of the possibility of such damages.
################################################################################################
<#
.SYNOPSIS
    manage Azure Service Tags in Azure User-Defined Routes (UDR)
.DESCRIPTION
    it will add for a specific Azure service tag the IP ranges from the JSON file into the UDR (ServiceTagUDR).
    every ServiceTagUDR be in the naming format
      AStUdr-[ServiceTag]-[###]-[ChangeNr]-[date of update]
.NOTES  
    File Name  : <ScriptName>.ps1
    Author     : <Author>
.LINK  
    
.EXAMPLE
.\<ScriptName>
.\<ScriptName> -cloudEnv "<PathToLogFile>" -LogReset -EventLog -EnableDebug -EnableVerbose

.PARAMETER -cloudEnv
   choose the cloud environment ['Public','USGov','China','Germany']
.PARAMETER -serviceTag
   specify the service tag name to use in the operation
.PARAMETER -operation
   operation to perform ['add','update','delete']
.PARAMETER -subscription
   Azure subscription  where the route table exist
.PARAMETER -resourceGroup
   Azure resource group name where the route table exist
.PARAMETER -routeTable
   route table to operate on
#>

######### Parameters #########
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Public','USGov','China','Germany')]
    [string] $cloudEnv = "Public", 
    
    [Parameter(Mandatory = $true)]
    [array] $serviceTag,

    [Parameter(Mandatory = $true)]
    [ValidateSet('add','remove')]
    [string] $operation, 
    
#    [Parameter(Mandatory = $true)]
#    [string] $subscription, 
    
    [Parameter(Mandatory = $true)]
    [string] $resourceGroup, 
    
    [Parameter(Mandatory = $true)]
    [string] $routeTableName,

    [Parameter(Mandatory = $false)]
    [string] $routePrefix = "STUDR"
)

######### Functions #########
function get-ServiceTagDownloadUri {
    # .SYNOPSIS  
    #    Returns the download URI of the Azure IP Ranges and Service Tags of the specified cloud environment
    # .DESCRIPTION  
    #    Returns the download URI of the Azure IP Ranges and Service Tags of the specified cloud environment
    #  .NOTES  
    #    Author: Holger Reiners, Microsoft, 2020
    #  
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Public','USGov','China','Germany')]
        [string] $cloudEnv
    )

    # URL / URI for cloud environment:
    #  - Public Cloud - https://www.microsoft.com/download/details.aspx?id=56519 / "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"; 
    #  - US Government - https://www.microsoft.com/download/details.aspx?id=57063 / "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57063"; 
    #  - China - https://www.microsoft.com/download/details.aspx?id=57062 / "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57062"; 
    #  - Germany - https://www.microsoft.com/download/details.aspx?id=57064 / "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57064"; 

    switch($cloudEnv) {
        "Public" {$downloadUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"}
        "USGov" {$downloadUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57063"}
        "China" {$downloadUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57062"}
        "Germany" {$downloadUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57064"}
    }

    $downloadPage = Invoke-WebRequest -Uri $downloadUrl;
    $downloadUri = ($downloadPage.RawContent.Split('"') -like "https://*/ServiceTags_*")[0];
    #Possible TODO Download only if change NR > last run

    Return $downloadUri
} # get-ServiceTagDownloadUri

function get-AzureDcIpJson {
    # .SYNOPSIS  
    #    
    # .DESCRIPTION  
    #    
    #  .NOTES  
    #    Author: Holger Reiners, Microsoft, 2020
    #  
    param (
        [Parameter(Mandatory = $true)]
        [string] $AzureDcIpUri
    )
    
    # init return value as NULL
    $dcIpJson = $null

    try {
        # download the Azure Datacenter IP JSON file
        $uriResponse = invoke-webrequest -Uri $downloadUri
        if ($uriResponse.StatusCode -eq 200) {
            $content = [System.Text.Encoding]::UTF8.GetString($uriResponse.Content)
            $dcIpJson = ConvertFrom-JSON $content
        }
    }
    catch {
        $dcIpJson = $null
    }
    
    Return $dcIpJson
} # get-AzureDcIpJson

function Template {
    # .SYNOPSIS  
    #    
    # .DESCRIPTION  
    #    
    #  .NOTES  
    #    Author: Holger Reiners, Microsoft, 2020
    #  
    param (
        [Parameter(Mandatory = $true)]
        [string] $ParameterInput
    )

    
    Return $ReturnObject
} # Template

function main {
    ### get cloud environment URL / URI
    $downloadUri = Get-ServiceTagDownloadUri $cloudEnv

    write-verbose ("working parameters")
    write-verbose ("  cloud environment : $cloudEnv")
    write-verbose ("  download URI      : $downloadUri")
    write-verbose ("  service tag       : $serviceTag")
    write-verbose ("  operation         : $operation")
    write-verbose ("  subscription      : $subscription")
    write-verbose ("  resource group    : $resourceGroup")
    write-verbose ("  routetable        : $routeTableName")

    # Get the Azure datacenter IP as JSON
    $AzureDcIpJson = get-AzureDcIpJson -AzureDcIpUri $downloadUri
    if ($AzureDcIpJson -eq $null) {
        throw "no Azure Datacenter IP JSON file downloaded!"
    }
    # set parameters from JSON
    $changeNumber = $AzureDcIpJson.changeNumber
    $cloud = $AzureDcIpJson.cloud

    # Get route table
    $routeTable = Get-AzRouteTable -ResourceGroupName $resourceGroup -Name $routeTableName
    if ($routeTable -eq $null) {
        throw "route table $routeTableName in ResourceGroupName $resourceGroup not found."
    }

    # process all service tags
    foreach ($serviceTagItem in $serviceTag) {
        write-verbose ("working on service tag item : $serviceTagItem")
        
        # TODO - Get Change Number of particular Service
        # TODO - verify the service tag change number with the route change number
        
        # remove existing routes for the service tag
        $prefix = "$routePrefix-$serviceTagItem"
        $routes = $routeTable.Routes | Where-Object {$_.Name -like "$routePrefix-$serviceTagItem*"}
        foreach ($route in $routes.Name) {
            write-verbose ("  REMOVE route : $route")
            Remove-AzRouteConfig -RouteTable $routeTable -Name $route | Out-Null
        }

        if ($operation -eq "add") {
            # add routes for the service tag
            $serviceTagName = $serviceTagItem
            $serviceTagRoutes = ($azureDcIpJson.values | Where-Object {$_.Name -eq $serviceTagName} | Select-Object -ExpandProperty properties).addressPrefixes
            
            #TODO
            #If routes would exceed 400 break
            if ($routeTable.Routes.Count + $serviceTagRoutes.count -gt 400){
                #do break stuff
            }

            $counter = 0
            $date = Get-Date -Format "yyyyMMdd"
            foreach ($serviceTagRoute in $serviceTagRoutes) {
                write-verbose "  $prefix-$counter-$cloud-$changeNumber-$date || $serviceTagRoute"
                $routeName = "$prefix-$counter-$cloud-$changeNumber-$date"
                Add-AzRouteConfig -RouteTable $routeTable -Name $routeName -AddressPrefix $serviceTagRoute -NextHopType Internet | Out-Null
                $counter ++
            }
            Write-Verbose "  Route count: $routeTable.Routes.Count"
        }
    } # foreach ServiceTagItem
    
    if ($routeTable.Routes.Count -le 400) {
        Write-Verbose "Update route table $routeTable"
        Set-AzRouteTable -RouteTable $routeTable | Out-Null
    }
            
} # main

main
trap {"Error found: $_"}