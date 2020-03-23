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
.\<ScriptName> -LogFile "<PathToLogFile>" -LogReset -EventLog -EnableDebug -EnableVerbose

.PARAMETER LogFile
   enables the log to file and specifies the log file.
.PARAMETER -LogReset
   will clear the log file
.PARAMETER -EventLog
   enables the logging to the Applicaton Eventlog
.PARAMETER -Debug
   enables the script debug messages
.PARAMETER -Verbose
   enables the script verbose messages
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Public','USGov','China','Germany')]
    [string] $cloudEnv = "Public", 
    
    [Parameter(Mandatory = $true)]
    [string] $serviceTag,

    [Parameter(Mandatory = $true)]
    [ValidateSet('add','update','delete')]
    [string] $operation, 
    
    [Parameter(Mandatory = $true)]
    [string] $subscription, 
    
    [Parameter(Mandatory = $true)]
    [string] $resourceGroup, 
    
    [Parameter(Mandatory = $true)]
    [string] $routeTable
)

######### MAIN

function Get-ServiceTagDownloadUri {
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

    Return $downloadUri
}

function Get-ServiceTagIpRangeJson {
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
        "Public" {$downloadUri = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"}
        "USGov" {$downloadUri = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57063"}
        "China" {$downloadUri = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57062"}
        "Germany" {$downloadUri = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57064"}
    }
    
    
    # Download current list of Azure Public IP ranges
    $downloadPage = Invoke-WebRequest -Uri $downloadUri;
    $jsonFileUri = ($downloadPage.RawContent.Split('"') -like "https://*/ServiceTags_*")[0]; 
    write-debug ("JSON file URI: " + $jsonFileUri)

    $uriResponse = (invoke-webrequest $jsonFileUri)
    $jsonResponse = [System.Text.Encoding]::UTF8.GetString($uriResponse.RawContent)
    $azureDcIpJson = ConvertFrom-JSON $jsonResponse
    
    Return $downloadUri
}

function derrest {
    
    # Download current list of Azure Public IP ranges
    $downloadPage = Invoke-WebRequest -Uri $downloadUri;
    $jsonFileUri = ($downloadPage.RawContent.Split('"') -like "https://*/ServiceTags_*")[0]; 
    write-debug ("JSON file URI: " + $jsonFileUri)

    $uriResponse = (invoke-webrequest $jsonFileUri)
    $jsonResponse = [System.Text.Encoding]::UTF8.GetString($uriResponse.RawContent)
    $azureDcIpJson = ConvertFrom-JSON $jsonResponse

    $serviceTagName = "APIManagement"
    $prefixes = ($azureDcIpJson.values | Where-Object {$_.Name -eq $serviceTagName} | Select-Object -ExpandProperty properties).addressPrefixes
    
    $counter = 0
    $date = Get-Date -Format "yyyyMMddTHHmmss"
    foreach ($prefix in $prefixes) {
        write-debug "UDR-$serviceTagName-$counter-$date || $prefix"
        $counter ++
    }
}

function main {
    ### get cloud environment URL / URI
    $downloadUri = Get-ServiceTagDownloadUri $cloudEnv

    write-debug ("working parameters")
    write-debug ("  cloud environment : $cloudEnv")
    write-debug ("  download URI      : $downloadUri")
    write-debug ("  service tag       : $serviceTag")
    write-debug ("  operation         : $operation")
    write-debug ("  subscription      : $subscription")
    write-debug ("  resource group    : $resourceGroup")
    write-debug ("  routetable        : $routeTable")

}

main
