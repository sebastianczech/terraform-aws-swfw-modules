### VPCS ###

module "vpc" {
  source = "../../modules/vpc"

  for_each = var.vpcs

  region          = var.region
  name            = "${var.name_prefix}${each.value.name}"
  cidr_block      = each.value.cidr_block
  subnets         = each.value.subnets
  nacls           = each.value.nacls
  security_groups = each.value.security_groups

  options = {
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"
  }
}

module "vpc_routes" {
  source = "../../modules/vpc_route"

  for_each = merge([
    for k, v in var.vpcs : {
      for i, j in v.routes : "${k}${i}" => merge(j, { vpc = k })
    }
  ]...)

  route_table_id   = module.vpc[each.value.vpc].route_tables[each.value.route_table].id
  to_cidr          = each.value.to_cidr
  destination_type = each.value.destination_type
  next_hop_type    = each.value.next_hop_type

  internet_gateway_id = each.value.next_hop_type == "internet_gateway" ? module.vpc[each.value.next_hop_key].internet_gateway.id : null
}

### IAM ROLES AND POLICIES ###

data "aws_caller_identity" "this" {}

data "aws_partition" "this" {}

resource "aws_iam_role_policy" "this" {
  for_each = { for vmseries in local.vmseries_instances : "${vmseries.group}-${vmseries.instance}" => vmseries }
  role     = module.bootstrap[each.key].iam_role_name
  policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DescribeAlarms"
      ],
      "Resource": [
        "arn:${data.aws_partition.this.partition}:cloudwatch:${var.region}:${data.aws_caller_identity.this.account_id}:alarm:*"
      ],
      "Effect": "Allow"
    }
  ]
}

EOF
}

### BOOTSTRAP PACKAGE
module "bootstrap" {
  source = "../../modules/bootstrap"

  for_each = { for vmseries in local.vmseries_instances : "${vmseries.group}-${vmseries.instance}" => vmseries }

  iam_role_name             = "${var.name_prefix}vmseries${each.value.instance}"
  iam_instance_profile_name = "${var.name_prefix}vmseries_instance_profile${each.value.instance}"

  prefix = var.name_prefix

  bootstrap_options     = merge(each.value.common.bootstrap_options, { hostname = "${var.name_prefix}${each.key}" })
  source_root_directory = "files"
}

### VM-Series INSTANCES

locals {
  vmseries_instances = flatten([for kv, vv in var.vmseries : [for ki, vi in vv.instances : { group = kv, instance = ki, az = vi.az, common = vv }]])
}

module "vmseries" {
  source = "../../modules/vmseries"

  for_each = { for vmseries in local.vmseries_instances : "${vmseries.group}-${vmseries.instance}" => vmseries }

  name              = "${var.name_prefix}${each.key}"
  vmseries_version  = each.value.common.panos_version
  ebs_kms_key_alias = each.value.common.ebs_kms_id

  interfaces = {
    for k, v in each.value.common.interfaces : k => {
      device_index       = v.device_index
      private_ips        = [v.private_ip[each.value.instance]]
      security_group_ids = try([module.vpc[each.value.common.vpc].security_group_ids[v.security_group]], [])
      source_dest_check  = try(v.source_dest_check, false)
      subnet_id          = module.vpc[v.vpc].subnets["${v.subnet_group}${each.value.az}"].id
      create_public_ip   = try(v.create_public_ip, false)
      eip_allocation_id  = try(v.eip_allocation_id[each.value.instance], null)
      ipv6_address_count = try(v.ipv6_address_count, null)
    }
  }

  bootstrap_options = join(";", compact(concat(
    ["vmseries-bootstrap-aws-s3bucket=${module.bootstrap[each.key].bucket_name}"],
    ["mgmt-interface-swap=${each.value.common.bootstrap_options["mgmt-interface-swap"]}"],
  )))

  iam_instance_profile = module.bootstrap[each.key].instance_profile_name
  ssh_key_name         = var.ssh_key_name
  tags                 = var.tags
}
