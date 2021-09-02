variable "name" {}
variable "public_key" {}
variable "cpu" {}
variable "memory" {}
variable "disk" {}
variable "image"{}

variable "vcenter" {}
variable "vsphere_user" {}
variable "vsphere_password" {}


variable "vsphere_folder" {}
variable "vsphere_datacenter" {}
variable "vsphere_datastore" {}
variable "vsphere_cluster" {}
variable "vsphere_network" {}
variable "vsphere_resource_pool" {}



terraform {
  required_providers {
    vsphere = {
      version = "1.24.3"
    }
  }

  
}


provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vcenter}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vsphere_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.vsphere_cluster}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vsphere_network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network_internal" {
  name          = "${var.vsphere_network_internal}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.image}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Render a part using a `template_file`
data "template_file" "script" {
  template = "${file("cloud-config.tpl")}"

  vars = {
    public_key = "${var.public_key}"
  }
}

# Render a multi-part cloud-init config making use of the part
# above, and other source files
data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.script.rendered}"
  }

}

resource "vsphere_virtual_machine" "vm" {
  name             = "${var.name}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder           = "${var.vsphere_folder}"

  num_cpus = "${var.cpu}"
  memory   = "${var.memory}"
  memory_hot_add_enabled = true
  cpu_hot_add_enabled = true
  nested_hv_enabled = true 
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  
  network_interface {
    network_id = "${data.vsphere_network.network_internal.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }


  extra_config = {
    "guestinfo.userdata.encoding" = "gzip+base64"
    "guestinfo.userdata" = "${data.template_cloudinit_config.config.rendered}"

  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
  }
}

output "private_ip" {
  value = "${vsphere_virtual_machine.vm.guest_ip_addresses[0]}"
}

output "public_ip" {
  value = "${vsphere_virtual_machine.vm.guest_ip_addresses[0]}"
}

output "hostname" {
  value = "${var.name}"
}
