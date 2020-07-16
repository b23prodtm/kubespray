# vagrant docker image

This image is used for the vagrant CI jobs. It is using the libvirt driver.

## Usage

```console
$ docker run --net host --rm -it -v /var/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock quay.io/kubespray/vagrant
$ vagrant up
Bringing machine 'k8s-1' up with 'libvirt' provider...
Bringing machine 'k8s-2' up with 'libvirt' provider...
Bringing machine 'k8s-3' up with 'libvirt' provider...
[...]
```
## Cache

You can set `/root/kubespray_cache` as a volume to keep cache between runs.

## Building

```shell
./build.sh v2.12.5
```
## MacOS and vagrant CI Jobs
When you build vagrant containers (alias boxes), the path ``/var/run/libvirt/libvirt-sock`
is not shared from OS X and is not known to Docker.
To allow vagrant find libvirt socket, change path `/var/' to some path like `/Users/Shared/` on Darwin boxes. The following will run a vagrant box, it follows:
```console
$ docker run --net host --rm -it -v /Users/Shared/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock quay.io/kubespray/vagrant
```
