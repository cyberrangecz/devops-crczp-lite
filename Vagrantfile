# -*- mode: ruby -*-

# vi: set ft=ruby :

dns1 = ENV["DNS1"] || "1.1.1.1"
dns2 = ENV["DNS2"] || "1.0.0.1"
cpu = ENV["CPU"] || 8
ram = ENV["RAM"] || 45056

# Component versions — set important versions here
box                   = ENV["BOX"]                   || "bento/ubuntu-24.04"
box_version           = ENV["BOX_VERSION"]           || "202508.03.0"
openstack_release     = ENV["OPENSTACK_RELEASE"]     || "2025.1"
ansible_core_version  = ENV["ANSIBLE_CORE_VERSION"]  || ">=2.17,<2.18.99"
tf_deployment_version = ENV["TF_DEPLOYMENT_VERSION"] || "v1.4.0"

Vagrant.configure(2) do |config|

  config.vm.box = box
  config.vm.box_version = box_version
  config.vm.hostname = "openstack"

  config.vm.network :private_network,
    ip: "10.1.2.10"

  config.vm.network :private_network,
    ip: "10.1.2.11",
    auto_config: false

  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = cpu
    libvirt.memory = ram
    libvirt.nested = true
    libvirt.machine_virtual_size = 250
  end

  # File provisioning - copy configuration and scripts
  config.vm.provision "file",
    source: "ansible.cfg",
    destination: "/tmp/ansible.cfg",
    run: "once"

  config.vm.provision "file",
    source: "scripts/",
    destination: "/tmp/",
    run: "once"

  # Shared folder configuration
  config.vm.synced_folder ".", "/vagrant"

  # Phase 1: System Setup
  config.vm.provision "system-setup",
    type: "shell",
    name: "System Setup and Package Installation",
    env: {
      "DNS1" => dns1,
      "DNS2" => dns2,
      "RAM" => ram.to_s
    },
    path: "scripts/01-system-setup.sh",
    run: "once"

  # Phase 2: OpenStack Deployment
  config.vm.provision "openstack-deployment",
    type: "shell",
    name: "OpenStack Deployment with Kolla-Ansible",
    env: {
      "OPENSTACK_RELEASE" => openstack_release,
      "ANSIBLE_CORE_VERSION" => ansible_core_version
    },
    path: "scripts/02-openstack-deploy.sh",
    run: "once",
    privileged: true

  # Phase 3: Infrastructure Deployment
  config.vm.provision "infrastructure-deployment",
    type: "shell",
    name: "Kubernetes and Application Infrastructure",
    env: {
      "DNS1" => dns1,
      "DNS2" => dns2,
      "TF_DEPLOYMENT_VERSION" => tf_deployment_version
    },
    path: "scripts/03-infrastructure-deploy.sh",
    run: "once",
    privileged: true

  # Phase 4: Final Setup
  config.vm.provision "final-setup",
    type: "shell",
    name: "Final Configuration and Information Display",
    path: "scripts/04-final-setup.sh",
    run: "once",
    privileged: true
end
