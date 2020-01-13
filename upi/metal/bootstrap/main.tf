resource "matchbox_profile" "bootstrap" {
  name   = "${var.cluster_id}-bootstrap"
  kernel = "${var.pxe_kernel}"

  initrd = [
    "${var.pxe_initrd}",
  ]

  args = [
    "${var.pxe_kernel_args}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?cluster_id=${var.cluster_id}&role=bootstrap",
  ]

  raw_ignition = "${replace(var.igntion_config_content,"\"networkd\":{}",format("\"networkd\":{\"units\":[{\"name\":\"00-eth0.network\",\"contents\":\"[Match]\\nName=eth0\\n\\n[Network]\\nDHCP=ipv4\\nAddress=%s\\nGateway=%s\"}]}",packet_device.bootstrap.network.1.address,packet_device.bootstrap.network.1.gateway))}"

  depends_on = ["packet_device.bootstrap"]
}

resource "matchbox_group" "bootstrap" {
  name    = "${var.cluster_id}-bootstrap"
  profile = "${matchbox_profile.bootstrap.name}"

  selector {
    cluster_id = "${var.cluster_id}"
    role       = "bootstrap"
  }
}

resource "packet_device" "bootstrap" {
  hostname         = "${var.cluster_id}-bootstrap"
  plan             = "c1.small.x86"
  facilities       = ["${var.packet_facility}"]
  operating_system = "custom_ipxe"
  ipxe_script_url  = "${var.matchbox_http_endpoint}/ipxe?cluster_id=${var.cluster_id}&role=bootstrap"
  billing_cycle    = "hourly"
  project_id       = "${var.packet_project_id}"
}
