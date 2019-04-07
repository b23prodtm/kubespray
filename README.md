￼

Deploy a Production Ready Kubernetes Cluster

If you have questions, check the [documentation](https://kubespray.io) and join us on the [kubernetes slack](https://kubernetes.slack.com), channel **\#kubespray**.
You can get your invite [here](http://slack.k8s.io/)

-   Can be deployed on **AWS, GCE, Azure, OpenStack, vSphere, Packet (bare metal), Oracle Cloud Infrastructure (Experimental), or Baremetal**
-   **Highly available** cluster
-   **Composable** (Choice of the network plugin for instance)
-   Supports most popular **Linux distributions**
-   **Continuous integration tests**

Quick Start
-----------

To deploy the cluster you can use :

### Ansible with Raspberry Pis cluster
~~Raspian 9 (arm, armv7l) is installed on PIs systems.~~ Ubuntu 18.04 bionic preinstalled server for Raspberries, [Download and flash the classic Server for ARM64](https://wiki.ubuntu.com/ARM/RaspberryPi). Also for Raspberry see current Pull Requests:

- [ARM](https://github.com/kubernetes-sigs/kubespray/pull/4261)
- [ARM64](https://github.com/kubernetes-sigs/kubespray/pull/4171)

#### Ansible version

Ansible v2.7.0 is failing and/or produce unexpected results due to [ansible/ansible/issues/46600](https://github.com/ansible/ansible/issues/46600)

#### Usage

    # Install pip3 [from python](https://pip.readthedocs.io/en/stable/installing/)
    sudo python3 get-pip.py

    # Install dependencies from ``requirements.txt``
    sudo pip3 install -r requirements.txt

    # Copy ``inventory/sample`` as ``inventory/mycluster``
    cp -rfp inventory/sample inventory/mycluster

    # Update Ansible inventory file with inventory builder . Single master IP is possible, see nodes with bastion
    declare -a IPS=(192.168.0.16 192.168.0.17)
    CONFIG_FILE=inventory/mycluster/hosts.ini python3 contrib/inventory_builder/inventory.py ${IPS[@]}
    cat inventory/mycluster/hosts.ini
    # bastion single master looks like `raspberrypi ansible_ssh_host=192.168.0.16 ip=192.168.0.16` ansible_host=192.168.0.16  ansible_user=pi" # replace 'pi' with 'ubuntu' or any other user
    # Review and change parameters under ``inventory/mycluster/group_vars``
    cat inventory/mycluster/group_vars/all/all.yml
    cat inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml

    # You can ssh-copy-id to Ansible inventory hosts permanently for the pi user
    declare PI=pi # replace 'pi' with 'ubuntu' or any other user
    for ip in ${IPS[@]}; do ssh-copy-id $PI@$ip; done
    # Enable SSH interface and PermitRootLogin over ssh in Raspberry    
    for ip in ${IPS[@]}; do
      ssh $PI@$ip sudo bash -c "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config";
      ssh $PI@$ip cat /etc/ssh/sshd_config | grep PermitRootLogin;
     # To install etcd on nodes, Go lang is needed
      ssh $PI@$ip sudo apt-get install golang -y;
     # Ansible is reported as a trusted repository
      ssh $PI@$ip sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367;
     # deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main

     # Get docker-ce (Read Ubuntu LTS https://docs.docker.com/install/linux/docker-ce/ubuntu/)
      ssh $PI@$pi sudo apt-get remove docker docker-engine docker.io containerd runc -y;
     # Install packages to allow apt to use a repository over HTTPS
      ssh $PI@$pi sudo apt-get update && sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y;
     # Add Docker’s official GPG key
      ssh $PI@$pi curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -;
     # Use the following command to set up the stable repository.
      ssh $PI@$pi sudo add-apt-repository "deb [arch=arm64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable";

     # Install Docker Community Edition
      ssh $PI@$pi sudo apt-get update && sudo apt-get install docker-ce -y;
     # Install the latest version of Docker CE and containerd
      ssh $PI@$pi sudo apt-get install docker-ce-cli containerd.io -y;

    # The kube user which owns k8s daemons must be added to Ubuntu group.
      ssh $PI@$pi sudo usermod -a -G ubuntu kube;
    done

    # Adjust the ansible_memtotal_mb to your Raspberry specs
    cat roles/kubernetes/preinstall/tasks/0020-verify-settings.yml | grep -b2 'that: ansible_memtotal_mb'

    # Shortcut to actually set up the playbook on hosts:
    scripts/setup_playbook.sh
    # or you can use the extended version as well
    # ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -v --private-key=~/.ssh/id_rsa  

See [docs](./docs/ansible.md)

>Note: When Ansible is already installed via system packages on the control machine, other python packages installed via `sudo pip3 install -r requirements.txt` will go to a different directory tree (e.g. `/usr/local/lib/python2.7/dist-packages` on Ubuntu) from Ansible's (e.g. `/usr/lib/python2.7/dist-packages/ansible` still on Ubuntu).
As a consequence, `ansible-playbook` command will fail with:
```
ERROR! no action detected in task. This often indicates a misspelled module name, or incorrect module path.
```
probably pointing on a task depending on a module present in requirements.txt (i.e. "unseal vault").

One way of solving this would be to uninstall the Ansible package and then, to install it via pip3 but it is not always possible.
A workaround consists of setting `ANSIBLE_LIBRARY` and `ANSIBLE_MODULE_UTILS` environment variables respectively to the `ansible/modules` and `ansible/module_utils` subdirectories of pip3 packages installation location, which can be found in the Location field of the output of `pip3 show [package]` before executing `ansible-playbook`.

#### Known issues :
See [docs](./docs/ansible.md)

- ModuleNotFoundError: No module named 'ruamel'
```Traceback (most recent call last):
  File "contrib/inventory_builder/inventory.py", line 36, in <module>
    from ruamel.yaml import YAML
```
Please install inventory builder python libraries.
>  sudo pip3 install -r contrib/inventory_builder/requirements.txt

- CGROUPS_MEMORY missing to use ```kubeadm init```

    [ERROR SystemVerification]: missing cgroups: memory

The Linux kernel must be loaded with special cgroups enabled. Add the following to the kernel parameters:

    cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1

E.g. : Raspberry Ubuntu Preinstalled server uses u-boot, then in ssh session run as regular user with sudo privileges:

    sed "$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/" /boot/firmware/cmdline.txt | sudo tee /boot/firmware/cmdline.txt
    reboot

I see the msg: "Timed out (12s) waiting for privileges escalation"

The ansible_user or --become_user must gain root privileges without password prompt. That's simply to edit the sudoers and add NOPASSWD: ALL to %admin and %sudo user group. E.g. from ansible host shell :

    ssh <ansible_user>@<bastion-ip> 'sudo visudo; sudo reboot'

- I may not be able to build a playbook on Arm, armv7l architectures Issues with systems such as Rasbian 9 and the Raspberries first and second generation. There are some issue kubernetes-sigs/kubespray#4261 to obtain 32 bits binary compatibility on those systems. Please post a comment if you find a way to enable 32 bits support for the k8s stack.

- Kubeadm 1.10.1 known to feature arm64 binary in googlestorage.io

- When you see the Error : no PUBKEY ... could be received from GPG Look at https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#latest-releases-via-apt-debian

- Deploy Kubespray with Ansible Playbook to raspberrypi The option -b is required, as for example writing SSL keys in /etc/, installing packages and interacting with various systemd daemons. Without -b argument the playbook would fall to start !

ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b -v --become-user=root --private-key=~/.ssh/id_rsa

- ```scripts/setup_playbook.sh```
 command will fail with:

    TASK [kubernetes/preinstall : Stop if ip var does not match local ips]

    fatal: [raspberrypi]: FAILED! => {
        "assertion": "ip in ansible_all_ipv4_addresses",
        "changed": false,
        "evaluated_to": false,
        "msg": "Assertion failed"
    }

The host *ip* set in ```inventory/<mycluster>/hosts.ini``` is not the docker network interface (iface). Run with ssh@... terminal : ```ifconfig docker0``` to find the ipv4 address that is attributed to the docker0 iface. E.g. _172.17.0.1_

- Error:  open /etc/ssl/etcd/ssl/admin-<hostname>.pem: permission denied

The file located at /etc/ssl/etcd is owned by another user than Ubuntu and cannot be accessed by Ansible. Please change the file owner:group to ```ubuntu:ubuntu``` or the *ansible_user* or your choice.

      ssh <ansible_user>@<bastion-ip> 'sudo chown ubuntu:ubuntu -R /etc/ssl/etcd/'

### Vagrant

For Vagrant we need to install python dependencies for provisioning tasks.
Check if Python3 and pip3 are installed:

    python3 -V && pip3 -V

If this returns the version of the software, you're good to go. If not, download and install Python from here <https://www.python.org/downloads/source/>
Install the necessary requirements

    sudo pip3 install -r requirements.txt
    vagrant up

Documents
---------

-   [Requirements](#requirements)
-   [Kubespray vs ...](docs/comparisons.md)
-   [Getting started](docs/getting-started.md)
-   [Ansible inventory and tags](docs/ansible.md)
-   [Integration with existing ansible repo](docs/integration.md)
-   [Deployment data variables](docs/vars.md)
-   [DNS stack](docs/dns-stack.md)
-   [HA mode](docs/ha-mode.md)
-   [Network plugins](#network-plugins)
-   [Vagrant install](docs/vagrant.md)
-   [CoreOS bootstrap](docs/coreos.md)
-   [Debian Jessie setup](docs/debian.md)
-   [openSUSE setup](docs/opensuse.md)
-   [Downloaded artifacts](docs/downloads.md)
-   [Cloud providers](docs/cloud.md)
-   [OpenStack](docs/openstack.md)
-   [AWS](docs/aws.md)
-   [Azure](docs/azure.md)
-   [vSphere](docs/vsphere.md)
-   [Packet Host](docs/packet.md)
-   [Large deployments](docs/large-deployments.md)
-   [Upgrades basics](docs/upgrades.md)
-   [Roadmap](docs/roadmap.md)

Supported Linux Distributions
-----------------------------

-   **Container Linux by CoreOS**
-   **Debian** Buster, Jessie, Stretch, Wheezy
-   **Ubuntu** 16.04, 18.04
-   **CentOS/RHEL** 7
-   **Fedora** 28
-   **Fedora/CentOS** Atomic
-   **openSUSE** Leap 42.3/Tumbleweed
• Ubuntu 16.04, 18.04 (Raspberries)

Note: Upstart/SysV init based OS types are not supported.

Supported Components
--------------------

-   Core
    -   [kubernetes](https://github.com/kubernetes/kubernetes) v1.13.5
    -   [etcd](https://github.com/coreos/etcd) v3.2.24
    -   [docker](https://www.docker.com/) v18.06 (see note)
    -   [rkt](https://github.com/rkt/rkt) v1.21.0 (see Note 2)
    -   [cri-o](http://cri-o.io/) v1.11.5 (experimental: see [CRI-O Note](docs/cri-o.md). Only on centos based OS)
-   Network Plugin
    -   [calico](https://github.com/projectcalico/calico) v3.4.0
    -   [canal](https://github.com/projectcalico/canal) (given calico/flannel versions)
    -   [cilium](https://github.com/cilium/cilium) v1.3.0
    -   [contiv](https://github.com/contiv/install) v1.2.1
    -   [flanneld](https://github.com/coreos/flannel) v0.11.0
    -   [kube-router](https://github.com/cloudnativelabs/kube-router) v0.2.1
    -   [multus](https://github.com/intel/multus-cni) v3.1.autoconf
    -   [weave](https://github.com/weaveworks/weave) v2.5.1
-   Application
    -   [cephfs-provisioner](https://github.com/kubernetes-incubator/external-storage) v2.1.0-k8s1.11
    -   [cert-manager](https://github.com/jetstack/cert-manager) v0.5.2
    -   [coredns](https://github.com/coredns/coredns) v1.4.0
    -   [ingress-nginx](https://github.com/kubernetes/ingress-nginx) v0.21.0

Note: The list of validated [docker versions](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.13.md) was updated to 1.11.1, 1.12.1, 1.13.1, 17.03, 17.06, 17.09, 18.06. kubeadm now properly recognizes Docker 18.09.0 and newer, but still treats 18.06 as the default supported version. The kubelet might break on docker's non-standard version numbering (it no longer uses semantic versioning). To ensure auto-updates don't break your cluster look into e.g. yum versionlock plugin or apt pin).

Note 2: rkt support as docker alternative is limited to control plane (etcd and
kubelet). Docker is still used for Kubernetes cluster workloads and network
plugins' related OS services. Also note, only one of the supported network
plugins can be deployed for a given single cluster.

Requirements
------------

-   **Ansible v2.6 (or newer) and python-netaddr is installed on the machine
    that will run Ansible commands**
-   **Jinja 2.9 (or newer) is required to run the Ansible Playbooks**
-   The target servers must have **access to the Internet** in order to pull docker images. Otherwise, additional configuration is required (See [Offline Environment](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/downloads.md#offline-environment))
-   The target servers are configured to allow **IPv4 forwarding**.
-   **Your ssh key must be copied** to all the servers part of your inventory.
-   The **firewalls are not managed**, you'll need to implement your own rules the way you used to.
    in order to avoid any issue during deployment you should disable your firewall.
-   If kubespray is ran from non-root user account, correct privilege escalation method
    should be configured in the target servers. Then the `ansible_become` flag
    or command parameters `--become or -b` should be specified.

Hardware:        
These limits are safe guarded by Kubespray. Actual requirements for your workload can differ. For a sizing guide go to the [Building Large Clusters](https://kubernetes.io/docs/setup/cluster-large/#size-of-master-and-master-components) guide.

-   Master
    - Memory: 1500 MB
-   Node
    - Memory: 1024 MB

Network Plugins
---------------

You can choose between 6 network plugins. (default: `calico`, except Vagrant uses `flannel`)

-   [flannel](docs/flannel.md): gre/vxlan (layer 2) networking.

-   [calico](docs/calico.md): bgp (layer 3) networking.

-   [canal](https://github.com/projectcalico/canal): a composition of calico and flannel plugins.

-   [cilium](http://docs.cilium.io/en/latest/): layer 3/4 networking (as well as layer 7 to protect and secure application protocols), supports dynamic insertion of BPF bytecode into the Linux kernel to implement security services, networking and visibility logic.

-   [contiv](docs/contiv.md): supports vlan, vxlan, bgp and Cisco SDN networking. This plugin is able to
    apply firewall policies, segregate containers in multiple network and bridging pods onto physical networks.

-   [weave](docs/weave.md): Weave is a lightweight container overlay network that doesn't require an external K/V database cluster.
    (Please refer to `weave` [troubleshooting documentation](http://docs.weave.works/weave/latest_release/troubleshooting.html)).

-   [kube-router](docs/kube-router.md): Kube-router is a L3 CNI for Kubernetes networking aiming to provide operational
    simplicity and high performance: it uses IPVS to provide Kube Services Proxy (if setup to replace kube-proxy),
    iptables for network policies, and BGP for ods L3 networking (with optionally BGP peering with out-of-cluster BGP peers).
    It can also optionally advertise routes to Kubernetes cluster Pods CIDRs, ClusterIPs, ExternalIPs and LoadBalancerIPs.

-   [multus](docs/multus.md): Multus is a meta CNI plugin that provides multiple network interface support to pods. For each interface Multus delegates CNI calls to secondary CNI plugins such as Calico, macvlan, etc.

The choice is defined with the variable `kube_network_plugin`. There is also an
option to leverage built-in cloud provider networking instead.
See also [Network checker](docs/netcheck.md).

Community docs and resources
----------------------------

-   [kubernetes.io/docs/getting-started-guides/kubespray/](https://kubernetes.io/docs/getting-started-guides/kubespray/)
-   [kubespray, monitoring and logging](https://github.com/gregbkr/kubernetes-kargo-logging-monitoring) by @gregbkr
-   [Deploy Kubernetes w/ Ansible & Terraform](https://rsmitty.github.io/Terraform-Ansible-Kubernetes/) by @rsmitty
-   [Deploy a Kubernetes Cluster with Kubespray (video)](https://www.youtube.com/watch?v=N9q51JgbWu8)

Tools and projects on top of Kubespray
--------------------------------------

-   [Digital Rebar Provision](https://github.com/digitalrebar/provision/blob/master/doc/integrations/ansible.rst)
-   [Terraform Contrib](https://github.com/kubernetes-sigs/kubespray/tree/master/contrib/terraform)

CI Tests
--------

[![Build graphs](https://gitlab.com/kubespray-ci/kubernetes-incubator__kubespray/badges/master/build.svg)](https://gitlab.com/kubespray-ci/kubernetes-incubator__kubespray/pipelines)

CI/end-to-end tests sponsored by Google (GCE)
See the [test matrix](docs/test_cases.md) for details.
