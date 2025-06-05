# -*- mode: ruby -*-

# vi: set ft=ruby :

git_key = ENV["GIT_KEY"] || ""
dns1 = ENV["DNS1"] || "1.1.1.1"
dns2 = ENV["DNS2"] || "1.0.0.1"
cpu = ENV["CPU"] || 8
ram = ENV["RAM"] || 45056

Vagrant.configure(2) do |config|

  config.vm.box = "generic/ubuntu2204"
  config.vm.box_version = "4.2.16"
  config.vm.hostname = "openstack"
  config.vm.network :private_network, ip: "10.1.2.10"
  config.vm.network :private_network, ip: "10.1.2.11", auto_config: false
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = cpu
    libvirt.memory = ram
    libvirt.nested = true
    libvirt.machine_virtual_size = 250
  end
  config.vm.provision "file", source: "ansible.cfg", destination: "/tmp/ansible.cfg"
  config.vm.synced_folder ".", "/vagrant"
  config.vm.provision "shell", env: {"DNS1"=>dns1,"DNS2"=>dns2,"GIT_KEY"=>git_key,"RAM"=>ram}, inline: <<-SHELL
    growpart /dev/vda 3
    lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
    resize2fs /dev/ubuntu-vg/ubuntu-lv
    sed -i "s/4.2.2.1/$DNS1/g" /etc/netplan/01-netcfg.yaml
    sed -i "s/4.2.2.2/$DNS2/g" /etc/netplan/01-netcfg.yaml
    sed -i "s/4.2.2.1/$DNS1/g" /etc/systemd/resolved.conf
    sed -i "s/4.2.2.2/$DNS2/g" /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    netplan apply
    echo "Waiting for network connection..."
    while ! ping -c 1 8.8.8.8 &> /dev/null; do
        echo "Network is unavailable. Retrying in 5 seconds..."
        sleep 5
    done
    echo "Network is available. Proceeding with Snap installation..."
    snap install core snapd
    snap install opentofu --classic
    snap install kubectl --classic
    snap install helm --classic
    apt update
    apt install -y python3-dev libffi-dev gcc libssl-dev python3-venv python3-docker pipenv jq
    apt install --reinstall ca-certificates
    python3 -m venv /root/kolla-ansible-venv
    source /root/kolla-ansible-venv/bin/activate
    pip3 install 'ansible-core>=2.17,<2.18.99'
    pip3 install git+https://opendev.org/openstack/kolla-ansible@stable/2025.1
    mkdir -p {/etc/kolla,/etc/ansible}
    mv /tmp/ansible.cfg /etc/ansible/ansible.cfg
    cp -r /root/kolla-ansible-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
    cp  /root/kolla-ansible-venv/share/kolla-ansible/ansible/inventory/* /root/
    sed -i -e '/\#kolla_base_distro/c\\kolla_base_distro: "ubuntu"' -e '/\#kolla_install_type/c\\kolla_install_type: "source"'\
           -e '/\#kolla_internal_vip_address/c\\kolla_internal_vip_address: "10.1.2.9"' -e '/\#network_interface/c\\network_interface: "eth1"'\
           -e '/\#neutron_external_interface/c\\neutron_external_interface: "eth2"'\
           -e '/\#nova_console/c\\nova_console: "spice"' /etc/kolla/globals.yml
    sed -i -e '/127.0.2.1/d' /etc/hosts

    kolla-ansible install-deps
    kolla-genpwd
    kolla-ansible bootstrap-servers -i /root/all-in-one
    kolla-ansible prechecks -i /root/all-in-one
    kolla-ansible deploy -i /root/all-in-one || kolla-ansible deploy -i /root/all-in-one
    kolla-ansible post-deploy -i /root/all-in-one

    deactivate
    echo "source /etc/kolla/admin-openrc.sh" >> /root/.bashrc
    pip3 install python-openstackclient -c https://releases.openstack.org/constraints/upper/2025.1
    source /etc/kolla/admin-openrc.sh
    sed -i 's/10.0/10.1/g' /root/kolla-ansible-venv/share/kolla-ansible/init-runonce
    /root/kolla-ansible-venv/share/kolla-ansible/init-runonce
    echo "    eth2: {}" >> /etc/netplan/50-vagrant.yaml
    ip link set eth2 up

    if openstack application credential show demo > /dev/null 2> /dev/null; then
      export OS_APPLICATION_CREDENTIAL_ID=`openstack application credential show demo -f json | jq '.id' | tr -d '"'`
    else
      export OS_APPLICATION_CREDENTIAL_ID=`openstack application credential create --unrestricted --role admin --role heat_stack_owner --secret password demo -f json | jq '.id' | tr -d '"'`
    fi
    export OS_AUTH_TYPE=v3applicationcredential
    export OS_INTERFACE=public
    export OS_APPLICATION_CREDENTIAL_SECRET=password
    unset OS_AUTH_PLUGIN OS_ENDPOINT_TYPE OS_PASSWORD OS_PROJECT_DOMAIN_NAME\
     OS_PROJECT_NAME OS_TENANT_NAME OS_USERNAME OS_USER_DOMAIN_NAME

    cd /root
    echo $GIT_KEY | base64 -d > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    rm /root/.ssh/id_rsa.pub
    echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > /root/.ssh/config
    git clone -b v1.1.0 https://github.com/cyberrangecz/devops-tf-deployment
    cd /root/devops-tf-deployment/tf-openstack-base
    tofu init
    export TF_VAR_external_network_name=public1
    export TF_VAR_dns_nameservers='["'$DNS1'","'$DNS2'"]'
    export TF_VAR_standard_small_disk="10"
    export TF_VAR_standard_medium_disk="16"
    tofu apply -auto-approve -var-file tfvars/vars-all.tfvars
    mkdir -p /root/.kube
    cp /root/devops-tf-deployment/tf-openstack-base/config /root/.kube/config
    export TF_VAR_acme_contact="demo@example.com"
    export TF_VAR_application_credential_id=$OS_APPLICATION_CREDENTIAL_ID
    export TF_VAR_application_credential_secret=$OS_APPLICATION_CREDENTIAL_SECRET
    export TF_VAR_enable_monitoring=true
    export TF_VAR_gen_user_count=10
    export TF_VAR_head_host=`tofu output -raw cluster_ip`
    export TF_VAR_kubernetes_api_url=https://`tofu output -raw cluster_ip`:6443/
    export TF_VAR_kubernetes_client_certificate=`tofu output -raw kubernetes_client_certificate`
    export TF_VAR_kubernetes_client_key=`tofu output -raw kubernetes_client_key`
    export TF_VAR_head_version="1.0.0"
    export TF_VAR_gen_users_version="1.0.0"
    export TF_VAR_postgres_version="1.0.0"
    export TF_VAR_man_flavor="standard.medium"
    export TF_VAR_man_image="debian-12-x86_64"
    export TF_VAR_openid_configuration_insecure=true
    export TF_VAR_os_auth_url=$OS_AUTH_URL
    export TF_VAR_os_region="RegionOne"
    export TF_VAR_proxy_host=`tofu output -raw proxy_host`
    export TF_VAR_proxy_key=`tofu output -raw proxy_key`
    export TF_VAR_users='{"crczp-admin"={iss="https://'$TF_VAR_head_host'/keycloak/realms/CRCZP",keycloakUsername="crczp-admin",keycloakPassword="password",email="crczp-admin@example.com",fullName="Demo Admin",givenName="Demo",familyName="Admin",admin=true}}'
    cd /root/devops-tf-deployment/tf-head-services
    cp provider.tf-os provider.tf
    cp cloud.tf-os cloud.tf
    sed -i -e "s/1.1.1.1/$DNS1/" -e "s/1.0.0.1/$DNS2/" values.yaml
    iterations=0
    while true; do
        ((iterations++))
        echo "Iteration: $iterations"
        result=$(kubectl get crd | grep middlewares.traefik.containo.us)
        if [ $? -eq 0 ]; then
            echo "K3s cluster ready:"
            echo "$result"
            break
        else
            echo "K3s cluster initializing. Retrying..."
        fi

        sleep 1
    done
    tofu init
    tofu apply -auto-approve
    echo "ALL DONE. Open https://$TF_VAR_head_host/"
    echo "Login: crczp-admin"
    echo "Password: password"
    echo "Monitoring admin password: `tofu output -raw monitoring_admin_password`"
    echo "Keycloak admin password: `tofu output -raw keycloak_password`"
    echo "Import demo-training with URL https://github.com/cyberrangecz/library-demo-training.git"
    echo "Import demo-training-adaptive with URL https://github.com/cyberrangecz/library-demo-training-adaptive.git"
    echo "Import junior-hacker with URL https://github.com/cyberrangecz/library-junior-hacker.git"
    echo "Import junior-hacker-adaptive with URL https://github.com/cyberrangecz/library-junior-hacker-adaptive.git"
    echo "Import locust-3302 with URL https://github.com/cyberrangecz/library-locust-3302.git"
    echo "Import secret-laboratory with URL https://github.com/cyberrangecz/library-secret-laboratory.git"
  SHELL
end
