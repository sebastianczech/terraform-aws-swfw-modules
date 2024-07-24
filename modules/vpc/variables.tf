variable "name" {
  description = "Name of the VPC to create or use."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "create_vpc" {
  description = "When set to `true` inputs are used to create a VPC, otherwise - to get data about an existing one (based on the `name` value)."
  default     = true
  type        = bool
}

variable "cidr_block" {
  description = "CIDR block to assign to a new VPC."
  default     = null
  type        = string
}

variable "secondary_cidr_blocks" {
  description = "Secondary CIDR block to assign to a new VPC."
  default     = []
  type        = list(string)
}

variable "assign_generated_ipv6_cidr_block" {
  description = "A boolean flag to assign AWS-provided /56 IPv6 CIDR block. [Defaults false](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#assign_generated_ipv6_cidr_block)"
  default     = null
  type        = bool
}

variable "enable_dns_support" {
  description = "A boolean flag to enable/disable DNS support in the VPC. [Defaults true](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#enable_dns_support)."
  default     = null
  type        = bool
}
variable "enable_dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC. [Defaults false](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#enable_dns_hostnames)."
  default     = null
  type        = bool
}

variable "create_dhcp_options" {
  description = "Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers."
  default     = false
  type        = bool
}
variable "domain_name" {
  description = "Specifies DNS name for DHCP options set. 'create_dhcp_options' needs to be enabled."
  default     = ""
  type        = string
}
variable "domain_name_servers" {
  description = "Specify a list of DNS server addresses for DHCP options set, default to AWS provided"
  default     = []
  type        = list(string)
}
variable "ntp_servers" {
  description = "Specify a list of NTP server addresses for DHCP options set, default to AWS provided"
  default     = []
  type        = list(string)
}

variable "instance_tenancy" {
  description = "VPC level [instance tenancy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc#instance_tenancy)."
  default     = null
  type        = string
}

variable "tags" {
  description = "Optional map of arbitrary tags to apply to all the created resources."
  default     = {}
  type        = map(string)
}

variable "vpc_tags" {
  description = "Optional map of arbitrary tags to apply to VPC resource."
  default     = {}
  type        = map(string)
}

variable "use_internet_gateway" {
  description = "If an existing VPC is provided and has IG attached, set to `true` to reuse it."
  default     = false
  type        = bool
}

variable "create_internet_gateway" {
  description = "Set to `true` to create IG and attach it to the VPC."
  default     = false
  type        = bool
}

variable "name_internet_gateway" {
  description = "Name of the IGW to create or use."
  default     = null
  type        = string
}

variable "route_table_internet_gateway" {
  description = "Name of route table for the IGW."
  default     = null
  type        = string
}

variable "create_vpn_gateway" {
  description = "When set to true, create VPN gateway and a dedicated route table."
  default     = false
  type        = bool
}
variable "vpn_gateway_amazon_side_asn" {
  description = "ASN for the Amazon side of the gateway."
  default     = null
  type        = string
}

variable "name_vpn_gateway" {
  description = "Name of the VPN gateway to create."
  default     = null
  type        = string
}

variable "route_table_vpn_gateway" {
  description = "Name of the route table for VPN gateway."
  default     = null
  type        = string
}

variable "subnets" {
  description = "Map of subnets to create or use."
  type = map(object({
    az                      = string
    cidr_block              = string
    group                   = string
    name                    = string
    nacl                    = optional(string)
    create_subnet           = optional(bool, true)
    create_route_table      = optional(bool, true)
    route_table_name        = optional(string)
    existing_route_table_id = optional(string)
    associate_route_table   = optional(bool, true)
    tags                    = optional(map(string))
  }))
}

variable "subnets_map_public_ip_on_launch" {
  description = "Enable/disable public IP on launch."
  default     = false
  type        = bool
}

variable "propagating_vgws" {
  description = "List of VGWs to propagate routes to."
  default     = []
  type        = list(string)
}

variable "nacls" {
  description = <<EOF
  The `nacls` variable is a map of maps, where each map represents an AWS NACL.

  Example:
  ```
  nacls = {
    trusted_path_monitoring = {
      name = "trusted-path-monitoring"
      rules = {
        allow_other_outbound = {
          rule_number = 200
          type        = "egress"
          protocol    = "-1"
          action      = "allow"
          cidr_block  = "0.0.0.0/0"
        }
        allow_inbound = {
          rule_number = 300
          type        = "ingress"
          protocol    = "-1"
          action      = "allow"
          cidr_block  = "0.0.0.0/0"
        }
      }
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    name = string
    rules = map(object({
      rule_number = number
      type        = string
      protocol    = string
      action      = string
      cidr_block  = string
      from_port   = optional(string)
      to_port     = optional(string)
    }))
  }))
}

variable "security_groups" {
  description = <<EOF
  The `security_groups` variable is a map of maps, where each map represents an AWS Security Group.
  The key of each entry acts as the Security Group name.
  List of available attributes of each Security Group entry:
  - `rules`: A list of objects representing a Security Group rule. The key of each entry acts as the name of the rule and
      needs to be unique across all rules in the Security Group.
      List of attributes available to define a Security Group rule:
      - `description`: Security Group description.
      - `type`: Specifies if rule will be evaluated on ingress (inbound) or egress (outbound) traffic.
      - `cidr_blocks`: List of CIDR blocks - for ingress, determines the traffic that can reach your instance. For egress
      Determines the traffic that can leave your instance, and where it can go.
      - `ipv6_cidr_blocks`: List of IPv6 CIDR blocks - for ingress, determines the traffic that can reach your instance. For egress
      Determines the traffic that can leave your instance, and where it can go. Defaults to null. 
      - `prefix_list_ids`: List of Prefix List IDs
      - `self`: security group itself will be added as a source to the rule.  Cannot be specified with cidr_blocks, or security_groups.
      - `source_security_groups`: list of security group IDs to be used as a source to the rule. Cannot be specified with cidr_blocks, or self.


  Example:
  ```
  security_groups = {
    vmseries_mgmt = {
      name = "vmseries_mgmt"
      rules = {
        all_outbound = {
          description = "Permit All traffic outbound"
          type        = "egress", from_port = "0", to_port = "0", protocol = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
        https = {
          description = "Permit HTTPS"
          type        = "ingress", from_port = "443", to_port = "443", protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # TODO: update here (replace 0.0.0.0/0 by your IP range)
        }
        ssh = {
          description = "Permit SSH"
          type        = "ingress", from_port = "22", to_port = "22", protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"] # TODO: update here (replace 0.0.0.0/0 by your IP range)
        }
        panorama_ssh = {
          description = "Permit Panorama SSH (Optional)"
          type        = "ingress", from_port = "22", to_port = "22", protocol = "tcp"
          cidr_blocks = ["10.0.0.0/8"]
        }
      }
    }
  }
  ```
  EOF

  default = {}
  type = map(object({
    name = string
    rules = map(object({
      description            = string
      type                   = string
      from_port              = string
      to_port                = string
      protocol               = string
      cidr_blocks            = list(string)
      ipv6_cidr_blocks       = optional(list(string))
      prefix_list_ids        = optional(list(string))
      self                   = optional(bool, false)
      source_security_groups = optional(list(string))
    }))
  }))
}
