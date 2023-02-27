@description('existing vent for resolver')
resource resolverVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: 'vnet-pocspoke-aue-001'
}
@description('new subnet for inbound connectivity to the dns resolver')
resource subnetdnsResource 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'snet-inbound-dnsresolver-aue-04'
  parent: resolverVnet
  properties: {
    addressPrefix: '10.150.44.0/24'
  }
}
@description('new subnets for outward cionnectivity from the dns resolver')
resource subnetdnsResource2 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'snet-outbound-dnsresolver-aue-05'
  parent: resolverVnet
  properties: {
    addressPrefix: '10.150.45.0/24'
  }
  dependsOn: [
    subnetdnsResource
  ]
}

@description('name of the dns private resolver')
param dnsResolverName string = 'dnsResolver'

@description('the location for resolver VNET and dns private resolver - Azure DNS Private Resolver available in specific region, refer the documenation to select the supported region for this deployment. For more information https://docs.microsoft.com/azure/dns/dns-private-resolver-overview#regional-availability')
@allowed([
  'australiaeast'
  'uksouth'
  'northeurope'
  'southcentralus'
  'westus3'
  'eastus'
  'northcentralus'
  'westcentralus'
  'eastus2'
  'westeurope'
  'centralus'
  'canadacentral'
  'brazilsouth'
  'francecentral'
  'swedencentral'
  'switzerlandnorth'
  'eastasia'
  'southeastasia'
  'japaneast'
  'koreacentral'
  'southafricanorth'
  'centralindia'
])
param location string

@description('name of the subnet that will be used for private resolver inbound endpoint')
param inboundSubnet string = 'snet-inbound-dnsresolver-aue-04'

@description('name of the subnet that will be used for private resolver outbound endpoint')
param outboundSubnet string = 'snet-outbound-dnsresolver-aue-05'

@description('name of the vnet link that links outbound endpoint with forwarding rule set')
param resolvervnetlink string = 'vnetlink'

@description('name of the forwarding ruleset')
param forwardingRulesetName string = 'forwardingRule'

@description('name of the forwarding rule name')
param forwardingRuleName string = 'auricomau'

@description('the target domain name for the forwarding ruleset')
param DomainName string = 'auri.com.au.'

@description('the list of target DNS servers ip address and the port number for conditional forwarding')
param targetDNS array = [
    {
      ipaddress: '10.89.160.11'
      port: 53
    }
    {
      ipaddress: '10.89.160.12'
      port: 53
    }
  ]

@description('dns resolver resource')
resource resolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: dnsResolverName
  location: location
  properties: {
    virtualNetwork: {
      id: resolverVnet.id
    }
  }
} 

@description('name of the forwarding rule name azure resource ')
param acrforwardingRuleName string = 'privatelinkazurecrio'

@description('the target domain name for the forwarding ruleset such as azure resource privatelink.azurecr.io')
param acrDomainName string = 'privatelink.azurecr.io.'

@description('the list of target DNS servers ip address and the port number for conditional forwarding')
param acrtargetDNS array = [
  {
    ipaddress: '10.150.40.5'
    port: 53
  }
]

resource inEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: resolver
  name: inboundSubnet
  location: location
  properties: {
    ipConfigurations: [
      {
        privateIpAllocationMethod: 'Dynamic'
        subnet: {
          id: '${resolverVnet.id}/subnets/${inboundSubnet}'
        }
      }
    ]
  }
}

resource outEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: resolver
  name: outboundSubnet
  location: location
  properties: {
    subnet: {
      id: '${resolverVnet.id}/subnets/${outboundSubnet}'
    }
  }
}

resource fwruleSet 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: forwardingRulesetName
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: outEndpoint.id
      }
    ]
  }
}

resource resolverLink 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = {
  parent: fwruleSet
  name: resolvervnetlink
  properties: {
    virtualNetwork: {
      id: resolverVnet.id
    }
  }
}

resource fwRules 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  parent: fwruleSet
  name: forwardingRuleName
  properties: {
    domainName: DomainName
    targetDnsServers: targetDNS
  }
}


resource acrfwRules 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  parent: fwruleSet
  name: acrforwardingRuleName
  properties: {
    domainName: acrDomainName
    targetDnsServers: acrtargetDNS
  }
}
