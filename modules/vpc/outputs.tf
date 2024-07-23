output "id" {
  description = "The VPC identifier (either created or pre-existing)."
  value       = local.vpc != null ? local.vpc.id : null
}

output "vpc" {
  description = "The entire VPC object (either created or pre-existing)."
  value       = local.vpc
}

output "name" {
  description = "The VPC Name Tag (either created or pre-existing)."
  value       = try(local.vpc.tags.Name, null)
}

output "has_secondary_cidrs" {
  value = contains([for k, v in aws_vpc_ipv4_cidr_block_association.this : length(v.id) > 0], true)
}

output "internet_gateway" {
  description = "The entire Internet Gateway object. It is null when `create_internet_gateway` is false."
  value       = var.create_internet_gateway ? try(aws_internet_gateway.this[0], null) : null
}

output "internet_gateway_route_table" {
  description = "The Route Table object created to handle traffic from Internet Gateway (IGW). It is null when `create_internet_gateway` is false."
  value       = var.create_internet_gateway ? try(aws_route_table.from_igw[0], null) : null
}

output "vpn_gateway" {
  description = "The entire Virtual Private Gateway object. It is null when `create_vpn_gateway` is false."
  value       = var.create_vpn_gateway ? try(aws_vpn_gateway.this[0], null) : null
}

output "vpn_gateway_route_table" {
  description = "The Route Table object created to handle traffic from Virtual Private Gateway (VGW). It is null when `create_vpn_gateway` is false."
  value       = var.create_vpn_gateway ? try(aws_route_table.from_vgw[0], null) : null
}

output "igw_as_next_hop_set" {
  description = "The object is suitable for use as `vpc_route` module's input `next_hop_set`."
  value = {
    type = "internet_gateway"
    id   = var.create_internet_gateway || var.use_internet_gateway ? local.internet_gateway.id : null
    ids  = {}
  }
}

output "vpn_gateway_as_next_hop_set" {
  description = "The object is suitable for use as `vpc_route` module's input `next_hop_set`."
  value = {
    type = "vpn_gateway"
    id   = var.create_vpn_gateway ? aws_vpn_gateway.this[0].id : null
    ids  = {}
  }
}

output "subnets" {
  value = { for k, v in local.subnets : k => merge(v, {
    group = var.subnets[k].group
    az    = var.subnets[k].az
  }) }
}

output "route_tables" {
  value = { for k, v in local.route_tables : k => merge(v, {
    group = var.subnets[k].group
    az    = var.subnets[k].az
  }) }
}

output "nacl_ids" {
  description = "Map of NACL -> ID (newly created)."
  value = {
    for k, nacl in aws_network_acl.this :
    k => nacl.id
  }
}

output "security_group_ids" {
  description = "Map of Security Group Name -> ID (newly created)."
  value = {
    for k, sg in aws_security_group.this :
    k => sg.id
  }
}