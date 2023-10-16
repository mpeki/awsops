#### Scripts and templates for creating the network infrastructure for a CuSSP account.

Templates must be applied in the following order:

1. `networks.yml` - VPC and subnets
2. `internet.yml` - Internet Gateway and Route Table for public traffic
3. `intranet.yml` - VPN Gateway and Route Table for private intranet traffic
4. `internet-security.yml` - Network ACLs for public traffic
5. `intranet-security.yml` - Network ACLs for private intranet traffic

For each template an associated bash script can be used to create and test the aws resources.
Execute the scripts without parameters or options to see the intended usage description.<br>
To configure the VPN you need to download the configuration based on your type of customer gateway