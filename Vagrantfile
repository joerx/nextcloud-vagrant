# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"

  # Libvirt has no good way to configure port forwarding, so Vagrant is setting up SSH tunnels instead
  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 443, host: 4443, host_ip: "127.0.0.1"

  # Requires NFS to be installed on the host system
  config.vm.synced_folder ".", "/workspace", type: "nfs", nfs_udp: false

  # Remove qemu_use_session if you want to use `qemu:///session` but some stuff may not work
  # Resource are roughly equivalent to a basic Linode or DigitalOcean VPS
  config.vm.provider "libvirt" do |lv|
    lv.cpus = 1
    lv.memory = 1024
    lv.qemu_use_session = false # "qemu:///system" (optional)
  end

  config.vm.provision "shell", path: "./setup.sh"
end
