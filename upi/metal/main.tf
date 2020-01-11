# ================MATCHBOX=====================

locals {
  kernel_args = [
    "console=tty0",
    "console=ttyS1,115200n8",
    "rd.neednet=1",

    # "rd.break=initqueue"
    "coreos.inst=yes",

    "coreos.inst.image_url=${var.pxe_os_image_url}",
    "coreos.inst.install_dev=sda",
    "coreos.inst.skip_media_check",
  ]

  pxe_kernel = "${var.pxe_kernel_url}"
  pxe_initrd = "${var.pxe_initrd_url}"
}

provider "matchbox" {
  endpoint    = "${var.matchbox_rpc_endpoint}"
  client_cert = "${file(var.matchbox_client_cert)}"
  client_key  = "${file(var.matchbox_client_key)}"
  ca          = "${file(var.matchbox_trusted_ca_cert)}"
}

resource "matchbox_profile" "default" {
  name = "${var.cluster_id}"
}

resource "matchbox_group" "default" {
  name    = "${var.cluster_id}"
  profile = "${matchbox_profile.default.name}"
}

# There is a race condition here.  We depend on creating the packet servers first
# so we can get the IP addresses.  We then need to get the matchbox profile created
# before the packet server creation makes it far enough to iPXE boot and needs to
# read this matchbox profile.  This is all because packet.net does not support DHCPv6,
# so we have to set these addresses statically.

resource "matchbox_profile" "master" {
  count  = "${var.master_count}"
  name   = "${var.cluster_id}-master-${count.index}"
  kernel = "${local.pxe_kernel}"

  initrd = [
    "${local.pxe_initrd}",
  ]

  args = [
    "${local.kernel_args}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?cluster_id=${var.cluster_id}&hostname=master-${count.index}.${var.cluster_domain}"
  ]

  raw_ignition = "${replace(file(var.master_ign_file),"\"networkd\":{}",format("\"networkd\":{\"units\":[{\"name\":\"00-eth0.network\",\"contents\":\"[Match]\\nName=eth0\\n\\n[Network]\\nDHCP=ipv4\\nAddress=%s\\nGateway=%s\"}]}",local.master_public_ipv6[count.index],local.master_public_ipv6_gw[count.index]))}"

  depends_on = ["packet_device.masters"]
}

resource "matchbox_profile" "worker" {
  count  = "${var.worker_count}"
  name   = "${var.cluster_id}-worker-${count.index}"
  kernel = "${local.pxe_kernel}"

  initrd = [
    "${local.pxe_initrd}",
  ]

  args = [
    "${local.kernel_args}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?cluster_id=${var.cluster_id}&hostname=worker-${count.index}.${var.cluster_domain}"
  ]

  raw_ignition = "${replace(file(var.worker_ign_file),"\"networkd\":{}",format("\"networkd\":{\"units\":[{\"name\":\"00-eth0.network\",\"contents\":\"[Match]\\nName=eth0\\n\\n[Network]\\nDHCP=ipv4\\nAddress=%s\\nGateway=%s\"}]}",local.worker_public_ipv6[count.index],local.worker_public_ipv6_gw[count.index]))}"

  depends_on = ["packet_device.workers"]
}

resource "matchbox_group" "master" {
  count   = "${var.master_count}"
  name    = "${var.cluster_id}-master-${count.index}"
  profile = "${matchbox_profile.master.*.name[count.index]}"

  selector {
    cluster_id = "${var.cluster_id}"
    hostname   = "master-${count.index}.${var.cluster_domain}"
  }
}

resource "matchbox_group" "worker" {
  count   = "${var.worker_count}"
  name    = "${var.cluster_id}-worker-${count.index}"
  profile = "${matchbox_profile.worker.*.name[count.index]}"

  selector {
    cluster_id = "${var.cluster_id}"
    hostname   = "worker-${count.index}.${var.cluster_domain}"
  }
}

# ================PACKET=====================

provider "packet" {}

locals {
  packet_facility = "sjc1"
}

resource "packet_device" "masters" {
  count            = "${var.master_count}"
  hostname         = "master-${count.index}.${var.cluster_domain}"
  plan             = "c1.small.x86"
  facilities       = ["ewr1"]
  operating_system = "custom_ipxe"
  ipxe_script_url  = "${var.matchbox_http_endpoint}/ipxe?cluster_id=${var.cluster_id}&hostname=master-${count.index}.${var.cluster_domain}"
  billing_cycle    = "hourly"
  project_id       = "${var.packet_project_id}"
}

resource "packet_device" "workers" {
  count            = "${var.worker_count}"
  hostname         = "worker-${count.index}.${var.cluster_domain}"
  plan             = "c1.small.x86"
  facilities       = ["ewr1"]
  operating_system = "custom_ipxe"
  ipxe_script_url  = "${var.matchbox_http_endpoint}/ipxe?cluster_id=${var.cluster_id}&hostname=worker-${count.index}.${var.cluster_domain}"
  billing_cycle    = "hourly"
  project_id       = "${var.packet_project_id}"
}

# ==============BOOTSTRAP=================

module "bootstrap" {
  source = "./bootstrap"

  pxe_kernel              = "${local.pxe_kernel}"
  pxe_initrd              = "${local.pxe_initrd}"
  pxe_kernel_args         = "${local.kernel_args}"
  matchbox_http_endpoint  = "${var.matchbox_http_endpoint}"
  igntion_config_content = "${file(var.bootstrap_ign_file)}"

  cluster_id = "${var.cluster_id}"

  packet_facility   = "ewr1"
  packet_project_id = "${var.packet_project_id}"
}

# ================AWS=====================

provider aws {
  region = "us-east-1"
}

locals {
  master_public_networks = "${flatten(packet_device.masters.*.network)}"
  master_public_ipv4     = "${data.template_file.master_ips.*.rendered}"
  master_public_ipv6     = "${data.template_file.master_ips_v6.*.rendered}"
  master_public_ipv6_gw  = "${data.template_file.master_gateways_v6.*.rendered}"

  worker_public_networks = "${flatten(packet_device.workers.*.network)}"
  worker_public_ipv4     = "${data.template_file.worker_ips.*.rendered}"
  worker_public_ipv6     = "${data.template_file.worker_ips_v6.*.rendered}"
  worker_public_ipv6_gw  = "${data.template_file.worker_gateways_v6.*.rendered}"

  ctrp_records           = "${compact(concat(list(var.bootstrap_dns ? module.bootstrap.device_ip : ""), local.master_public_ipv4))}"
  # TODO - Figure out why this doesn't work ...
  #  	* local.ctrp_records_v6: local.ctrp_records_v6: Couldn't find output "device_ip_v6" for module var: module.bootstrap.device_ip_v6
  #ctrp_records_v6        = "${compact(concat(list(var.bootstrap_dns ? module.bootstrap.device_ip_v6 : ""), local.master_public_ipv6))}"
}

data "template_file" "master_ips" {
  count    = "${var.master_count}"
  template = "${lookup(local.master_public_networks[count.index*3], "address")}"
}

data "template_file" "master_ips_v6" {
  count    = "${var.master_count}"
  template = "${lookup(local.master_public_networks[(count.index*3)+1], "address")}"
}

data "template_file" "master_gateways_v6" {
  count    = "${var.master_count}"
  template = "${lookup(local.master_public_networks[(count.index*3)+1], "gateway")}"
}

data "template_file" "worker_ips" {
  count    = "${var.worker_count}"
  template = "${lookup(local.worker_public_networks[count.index*3], "address")}"
}

data "template_file" "worker_ips_v6" {
  count    = "${var.worker_count}"
  template = "${lookup(local.worker_public_networks[(count.index*3)+1], "address")}"
}

data "template_file" "worker_gateways_v6" {
  count    = "${var.worker_count}"
  template = "${lookup(local.worker_public_networks[(count.index*3)+1], "gateway")}"
}

data "aws_route53_zone" "public" {
  name = "${var.public_r53_zone}"
}

resource "aws_route53_record" "ctrlp" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "A"
  ttl     = "60"
  name    = "api.${var.cluster_domain}"

  records = ["${local.ctrp_records}"]
}

#resource "aws_route53_record" "ctrlp_v6" {
#  zone_id = "${data.aws_route53_zone.public.zone_id}"
#  type    = "AAAA"
#  ttl     = "60"
#  name    = "api.${var.cluster_domain}"
#
#  records = ["${local.ctrp_records_v6}"]
#}

resource "aws_route53_record" "ctrlp_int" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "A"
  ttl     = "60"
  name    = "api-int.${var.cluster_domain}"

  records = ["${local.ctrp_records}"]
}

resource "aws_route53_record" "apps" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "A"
  ttl     = "60"
  name    = "*.apps.${var.cluster_domain}"

  records = ["${local.worker_public_ipv4}"]
}

resource "aws_route53_record" "apps_v6" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "AAAA"
  ttl     = "60"
  name    = "*.apps.${var.cluster_domain}"

  records = ["${local.worker_public_ipv6}"]
}

resource "aws_route53_record" "etcd_aaaa_nodes" {
  count   = "${var.master_count}"
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "AAAA"
  ttl     = "60"
  name    = "etcd-${count.index}.${var.cluster_domain}"
  records = ["${local.master_public_ipv6[count.index]}"]
}

resource "aws_route53_record" "master_aaaa_nodes" {
  count   = "${var.master_count}"
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "AAAA"
  ttl     = "60"
  name    = "master-${count.index}.${var.cluster_domain}"
  records = ["${local.master_public_ipv6[count.index]}"]
}

resource "aws_route53_record" "worker_aaaa_nodes" {
  count   = "${var.worker_count}"
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "AAAA"
  ttl     = "60"
  name    = "worker-${count.index}.${var.cluster_domain}"
  records = ["${local.worker_public_ipv6[count.index]}"]
}

resource "aws_route53_record" "etcd_cluster" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  type    = "SRV"
  ttl     = "60"
  name    = "_etcd-server-ssl._tcp.${var.cluster_domain}"
  records = ["${formatlist("0 10 2380 %s", aws_route53_record.etcd_aaaa_nodes.*.fqdn)}"]
}
