resource "libvirt_volume" "coreos_orig" {
  name   = "${var.cluster_id}-orig"
  source = var.image
}

resource "libvirt_volume" "bootstrap" {
  name           = "${var.cluster_id}-bootstrap"
  base_volume_id = libvirt_volume.coreos_orig.id
  size           = 17179869184
}

resource "libvirt_ignition" "bootstrap" {
  name    = "${var.cluster_id}-bootstrap.ign"
  content = var.ignition
}

resource "libvirt_domain" "bootstrap" {
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

