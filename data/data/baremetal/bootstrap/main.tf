resource "libvirt_pool" "bootstrap" {
  name = "${var.cluster_id}-bootstrap"
  type = "dir"
  path = "/var/lib/libvirt/openshift-images/${var.cluster_id}-bootstrap"
}

resource "libvirt_volume" "bootstrap" {
  name   = "${var.cluster_id}-bootstrap"
  pool   = libvirt_pool.bootstrap.name
  source = var.image
}

resource "libvirt_ignition" "bootstrap" {
  name    = "${var.cluster_id}-bootstrap.ign"
  content = var.ignition
}

resource "libvirt_domain" "bootstrap_single_interface" {
  count = var.provisioning_bridge == "" ? 1 : 0

  name = "${var.cluster_id}-bootstrap"

  memory = "6144"

  vcpu = "4"

  coreos_ignition = libvirt_ignition.bootstrap.id

  disk {
    volume_id = libvirt_volume.bootstrap.id
  }

  console {
    type        = "pty"
    target_port = 0
  }

  cpu = {
    mode = "host-passthrough"
  }

  network_interface {
    bridge = var.external_bridge
  }
}

resource "libvirt_domain" "bootstrap_dual_interface" {
  count = var.provisioning_bridge == "" ? 0 : 1

  name = "${var.cluster_id}-bootstrap"

  memory = "6144"

  vcpu = "4"

  coreos_ignition = libvirt_ignition.bootstrap.id

  disk {
    volume_id = libvirt_volume.bootstrap.id
  }

  console {
    type        = "pty"
    target_port = 0
  }

  cpu = {
    mode = "host-passthrough"
  }

  network_interface {
    bridge = var.external_bridge
  }

  network_interface {
    bridge = var.provisioning_bridge
  }
}

