### GENERAL
variable "region" {
  description = "AWS region used to deploy whole infrastructure"
  type        = string
}
variable "name_prefix" {
  description = "Prefix used in names for the resources (VPCs, EC2 instances, autoscaling groups etc.)"
  type        = string
}
variable "global_tags" {
  description = "Global tags configured for all provisioned resources"
}
variable "ssh_key_name" {
  description = "Name of the SSH key pair existing in AWS key pairs and used to authenticate to VM-Series or test boxes"
  type        = string
}

### VPC
variable "vpcs" {
  description = <<-EOF
  A map defining VPCs with security groups and subnets.

  Following properties are available:
  - `name`: VPC name
  - `cidr_block`: Object containing the IPv4 and IPv6 CIDR blocks to assign to a new VPC
  - `subnets`: map of subnets with properties
  - `routes`: map of routes with properties
  - `nacls`: map of network ACLs
  - `security_groups`: map of security groups

  Example:
  ```
  vpcs = {
    app1_vpc = {
      name = "app1-spoke-vpc"
      cidr_block = {
        ipv4 = "10.104.0.0/16"
      }
      subnets = {
        app1_vma    = { az = "a", cidr_block = "10.104.0.0/24", subnet_group = "app1_vm", name = "app1_vm1" }
        app1_vmb    = { az = "b", cidr_block = "10.104.128.0/24", subnet_group = "app1_vm", name = "app1_vm2" }
        app1_lba    = { az = "a", cidr_block = "10.104.2.0/24", subnet_group = "app1_lb", name = "app1_lb1" }
        app1_lbb    = { az = "b", cidr_block = "10.104.130.0/24", subnet_group = "app1_lb", name = "app1_lb2" }
        app1_gwlbea = { az = "a", cidr_block = "10.104.3.0/24", subnet_group = "app1_gwlbe", name = "app1_gwlbe1" }
        app1_gwlbeb = { az = "b", cidr_block = "10.104.131.0/24", subnet_group = "app1_gwlbe", name = "app1_gwlbe2" }
      }
      routes = {
        vm_default = {
          vpc           = "app1_vpc"
          subnet_group  = "app1_vm"
          to_cidr       = "0.0.0.0/0"
          next_hop_key  = "app1"
          next_hop_type = "transit_gateway_attachment"
        }
        gwlbe_default = {
          vpc           = "app1_vpc"
          subnet_group  = "app1_gwlbe"
          to_cidr       = "0.0.0.0/0"
          next_hop_key  = "app1_vpc"
          next_hop_type = "internet_gateway"
        }
        lb_default = {
          vpc           = "app1_vpc"
          subnet_group  = "app1_lb"
          to_cidr       = "0.0.0.0/0"
          next_hop_key  = "app1_inbound"
          next_hop_type = "gwlbe_endpoint"
        }
      }
      nacls = {}
      security_groups = {
        app1_vm = {
          name = "app1_vm"
          rules = {
            all_outbound = {
              description = "Permit All traffic outbound"
              type        = "egress", from_port = "0", to_port = "0", protocol = "-1"
              cidr_blocks = ["0.0.0.0/0"]
            }
            ssh = {
              description = "Permit SSH"
              type        = "ingress", from_port = "22", to_port = "22", protocol = "tcp"
              cidr_blocks = ["0.0.0.0/0", "10.104.0.0/16", "10.105.0.0/16"]
            }
            https = {
              description = "Permit HTTPS"
              type        = "ingress", from_port = "443", to_port = "443", protocol = "tcp"
              cidr_blocks = ["0.0.0.0/0", "10.104.0.0/16", "10.105.0.0/16"]
            }
            http = {
              description = "Permit HTTP"
              type        = "ingress", from_port = "80", to_port = "80", protocol = "tcp"
              cidr_blocks = ["0.0.0.0/0", "10.104.0.0/16", "10.105.0.0/16"]
            }
          }
        }
      }
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    name = string
    cidr_block = object({
      ipv4                  = optional(string)
      secondary_ipv4        = optional(list(string), [])
      assign_generated_ipv6 = optional(bool, false)
    })
    nacls = map(object({
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
    security_groups = map(object({
      name        = string
      description = optional(string, "Security group managed by Terraform")
      rules = map(object({
        description = string
        type        = string
        from_port   = string
        to_port     = string
        protocol    = string
        cidr_blocks = list(string)
      }))
    }))
    subnets = map(object({
      subnet_group            = string
      az                      = string
      name                    = string
      cidr_block              = string
      ipv6_cidr_block         = optional(string)
      nacl                    = optional(string)
      create_subnet           = optional(bool, true)
      create_route_table      = optional(bool, true)
      existing_route_table_id = optional(string)
      associate_route_table   = optional(bool, true)
      route_table_name        = optional(string)
      local_tags              = optional(map(string), {})
      tags                    = optional(map(string), {})
    }))
    routes = map(object({
      vpc           = string
      subnet_group  = string
      to_cidr       = string
      next_hop_key  = string
      next_hop_type = string
    }))
  }))
}

### TRANSIT GATEWAY
variable "tgw" {
  description = <<-EOF
  A object defining Transit Gateway.

  Following properties are available:
  - `create`: set to false, if existing TGW needs to be reused
  - `id`:  id of existing TGW or null
  - `name`: name of TGW to create or use
  - `asn`: ASN number
  - `route_tables`: map of route tables
  - `attachments`: map of TGW attachments

  Example:
  ```
  tgw = {
    create = true
    id     = null
    name   = "tgw"
    asn    = "64512"
    route_tables = {
      "from_security_vpc" = {
        create = true
        name   = "from_security"
      }
    }
    attachments = {
      security = {
        name                = "vmseries"
        vpc                 = "security_vpc"
        subnet_group        = "tgw_attach"
        route_table         = "from_security_vpc"
        propagate_routes_to = "from_spoke_vpc"
      }
    }
  }
  ```
  EOF
  default     = null
  type = object({
    create = bool
    id     = string
    name   = string
    asn    = string
    route_tables = map(object({
      create = bool
      name   = string
    }))
    attachments = map(object({
      name                = string
      vpc                 = string
      subnet_group        = string
      route_table         = string
      propagate_routes_to = string
    }))
  })
}

### NAT GATEWAY
variable "natgws" {
  description = <<-EOF
  A map defining NAT Gateways.

  Following properties are available:
  - `name`: name of NAT Gateway
  - `vpc`: VPC key
  - `subnet_group`: subnet_group key

  Example:
  ```
  natgws = {
    security_nat_gw = {
      name         = "natgw"
      vpc          = "security_vpc"
      subnet_group = "natgw"
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    name         = string
    vpc          = string
    subnet_group = string
  }))
}

### GATEWAY LOADBALANCER
variable "gwlbs" {
  description = <<-EOF
  A map defining Gateway Load Balancers.

  Following properties are available:
  - `name`: name of the GWLB
  - `vpc`: VPC key
  - `subnet_group`: subnet_group key

  Example:
  ```
  gwlbs = {
    security_gwlb = {
      name         = "security-gwlb"
      vpc          = "security_vpc"
      subnet_group = "gwlb"
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    name         = string
    vpc          = string
    subnet_group = string
  }))
}
variable "gwlb_endpoints" {
  description = <<-EOF
  A map defining GWLB endpoints.

  Following properties are available:
  - `name`: name of the GWLB endpoint
  - `gwlb`: key of GWLB
  - `vpc`: key of VPC
  - `subnet_group`: key of subnet_group
  - `act_as_next_hop`: set to `true` if endpoint is part of an IGW route table e.g. for inbound traffic
  - `from_igw_to_vpc`: VPC to which traffic from IGW is routed to the GWLB endpoint
  - `from_igw_to_subnet_group` : subnet_group to which traffic from IGW is routed to the GWLB endpoint

  Example:
  ```
  gwlb_endpoints = {
    security_gwlb_eastwest = {
      name            = "eastwest-gwlb-endpoint"
      gwlb            = "security_gwlb"
      vpc             = "security_vpc"
      subnet_group    = "gwlbe_eastwest"
      act_as_next_hop = false
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    name                     = string
    gwlb                     = string
    vpc                      = string
    subnet_group             = string
    act_as_next_hop          = bool
    from_igw_to_vpc          = optional(string)
    from_igw_to_subnet_group = optional(string)
  }))
}

### VM-SERIES
variable "vmseries_asgs" {
  description = <<-EOF
  A map defining Autoscaling Groups with VM-Series instances.

  Following properties are available:
  - `bootstrap_options`: VM-Seriess bootstrap options used to connect to Panorama
  - `panos_version`: PAN-OS version used for VM-Series
  - `ebs_kms_id`: alias for AWS KMS used for EBS encryption in VM-Series
  - `vpc`: key of VPC
  - `gwlb`: key of GWLB
  - `zones`: zones for the Autoscaling Group to be built in
  - `interfaces`: configuration of network interfaces for VM-Series used by Lamdba while provisioning new VM-Series in autoscaling group
  - `subinterfaces`: configuration of network subinterfaces used to map with GWLB endpoints
  - `asg`: the number of Amazon EC2 instances that should be running in the group (desired, minimum, maximum)
  - `scaling_plan`: scaling plan with attributes
    - `enabled`: `true` if automatic dynamic scaling policy should be created
    - `metric_name`: name of the metric used in dynamic scaling policy
    - `estimated_instance_warmup`: estimated time, in seconds, until a newly launched instance can contribute to the CloudWatch metrics
    - `target_value`: target value for the metric used in dynamic scaling policy
    - `statistic`: statistic of the metric. Valid values: Average, Maximum, Minimum, SampleCount, Sum
    - `cloudwatch_namespace`: name of CloudWatch namespace, where metrics are available (it should be the same as namespace configured in VM-Series plugin in PAN-OS)
    - `tags`: tags configured for dynamic scaling policy
  - `launch_template_version`: launch template version to use to launch instances
  - `instance_refresh`: instance refresh for ASG defined by several attributes (please README for module `asg` for more details)

  Example:
  ```
  vmseries_asgs = {
    main_asg = {
      bootstrap_options = {
        mgmt-interface-swap         = "enable"
        plugin-op-commands          = "panorama-licensing-mode-on,aws-gwlb-inspect:enable,aws-gwlb-overlay-routing:enable" # TODO: update here
        panorama-server             = ""                                                                                   # TODO: update here
        auth-key                    = ""                                                                                   # TODO: update here
        dgname                      = ""                                                                                   # TODO: update here
        tplname                     = ""                                                                                   # TODO: update here
        dhcp-send-hostname          = "yes"                                                                                # TODO: update here
        dhcp-send-client-id         = "yes"                                                                                # TODO: update here
        dhcp-accept-server-hostname = "yes"                                                                                # TODO: update here
        dhcp-accept-server-domain   = "yes"                                                                                # TODO: update here
      }

      panos_version = "10.2.3"        # TODO: update here
      ebs_kms_id    = "alias/aws/ebs" # TODO: update here

      vpc               = "security_vpc"
      gwlb              = "security_gwlb"

      interfaces = {
        private = {
          device_index   = 0
          security_group = "vmseries_private"
          subnet_group = "private"
          create_public_ip  = false
          source_dest_check = false
        }
        mgmt = {
          device_index   = 1
          security_group = "vmseries_mgmt"
          subnet_group = "mgmt"
          create_public_ip  = true
          source_dest_check = true
        }
        public = {
          device_index   = 2
          security_group = "vmseries_public"
          subnet_group = "public"
          create_public_ip  = false
          source_dest_check = false
        }
      }

      subinterfaces = {
        inbound = {
          app1 = {
            gwlb_endpoint = "app1_inbound"
            subinterface  = "ethernet1/1.11"
          }
          app2 = {
            gwlb_endpoint = "app2_inbound"
            subinterface  = "ethernet1/1.12"
          }
        }
        outbound = {
          only_1_outbound = {
            gwlb_endpoint = "security_gwlb_outbound"
            subinterface  = "ethernet1/1.20"
          }
        }
        eastwest = {
          only_1_eastwest = {
            gwlb_endpoint = "security_gwlb_eastwest"
            subinterface  = "ethernet1/1.30"
          }
        }
      }

      asg = {
        desired_cap                     = 0
        min_size                        = 0
        max_size                        = 4
        lambda_execute_pip_install_once = true
      }

      scaling_plan = {
        enabled                   = true
        metric_name               = "panSessionActive"
        estimated_instance_warmup = 900
        target_value              = 75
        statistic                 = "Average"
        cloudwatch_namespace      = "asg-vmseries"
        tags = {
          ManagedBy = "terraform"
        }
      }

      launch_template_version = "1"

      instance_refresh = {
        strategy = "Rolling"
        preferences = {
          checkpoint_delay             = 3600
          checkpoint_percentages       = [50, 100]
          instance_warmup              = 1200
          min_healthy_percentage       = 50
          skip_matching                = false
          auto_rollback                = false
          scale_in_protected_instances = "Ignore"
          standby_instances            = "Ignore"
        }
        triggers = []
      }

      delicense = {
        enabled = true
        ssm_param_name = "example_param_store_delicense" # TODO: update here
      }
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    bootstrap_options = object({
      mgmt-interface-swap         = string
      plugin-op-commands          = string
      panorama-server             = string
      auth-key                    = string
      dgname                      = string
      tplname                     = string
      dhcp-send-hostname          = string
      dhcp-send-client-id         = string
      dhcp-accept-server-hostname = string
      dhcp-accept-server-domain   = string
    })

    panos_version = string
    ebs_kms_id    = string

    vpc  = string
    gwlb = string

    zones = map(any)

    interfaces = map(object({
      device_index      = number
      security_group    = string
      subnet_group      = string
      create_public_ip  = bool
      source_dest_check = bool
    }))

    subinterfaces = map(map(object({
      gwlb_endpoint = string
      subinterface  = string
    })))

    asg = object({
      desired_cap                     = number
      min_size                        = number
      max_size                        = number
      lambda_execute_pip_install_once = bool
    })

    scaling_plan = object({
      enabled                   = bool
      metric_name               = string
      estimated_instance_warmup = number
      target_value              = number
      statistic                 = string
      cloudwatch_namespace      = string
      tags                      = map(string)
    })

    launch_template_version = string

    instance_refresh = object({
      strategy = string
      preferences = object({
        checkpoint_delay             = number
        checkpoint_percentages       = list(number)
        instance_warmup              = number
        min_healthy_percentage       = number
        skip_matching                = bool
        auto_rollback                = bool
        scale_in_protected_instances = string
        standby_instances            = string
      })
      triggers = list(string)
    })

    delicense = object({
      enabled        = bool
      ssm_param_name = string
    })
  }))
}

### PANORAMA
variable "panorama_attachment" {
  description = <<-EOF
  A object defining TGW attachment and CIDR for Panorama.

  Following properties are available:
  - `transit_gateway_attachment_id`: ID of attachment for Panorama
  - `vpc_cidr`: CIDR of the VPC, where Panorama is deployed

  Example:
  ```
  panorama = {
    transit_gateway_attachment_id = "tgw-attach-123456789"
    vpc_cidr                      = "10.255.0.0/24"
  }
  ```
  EOF
  default     = null
  type = object({
    transit_gateway_attachment_id = string
    vpc_cidr                      = string
  })
}

### SPOKE VMS
variable "spoke_vms" {
  description = <<-EOF
  A map defining VMs in spoke VPCs.

  Following properties are available:
  - `az`: name of the Availability Zone
  - `vpc`: key of the VPC (needs to be one of the keys in map `vpcs`)
  - `subnet_group`: key of the subnet_group
  - `security_group`: security group assigned to ENI used by VM
  - `type`: EC2 type VM

  Example:
  ```
  spoke_vms = {
    "app1_vm01" = {
      az             = "eu-central-1a"
      vpc            = "app1_vpc"
      subnet_group   = "app1_vm"
      security_group = "app1_vm"
      type           = "t2.micro"
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    az             = string
    vpc            = string
    subnet_group   = string
    security_group = string
    type           = string
  }))
}

### SPOKE LOADBALANCERS
variable "spoke_lbs" {
  description = <<-EOF
  A map defining Network Load Balancers deployed in spoke VPCs.

  Following properties are available:
  - `vpc`: key of the VPC
  - `subnet_group`: key of the subnet_group
  - `vms`: keys of spoke VMs

  Example:
  ```
  spoke_lbs = {
    "app1-nlb" = {
      vpc          = "app1_vpc"
      subnet_group = "app1_lb"
      vms          = ["app1_vm01", "app1_vm02"]
    }
  }
  ```
  EOF
  default     = {}
  type = map(object({
    vpc          = string
    subnet_group = string
    vms          = list(string)
  }))
}
