#!/usr/bin/env bash
declare -a version=(v1.10.0 v1.10.1 v1.10.11 v1.10.2 v1.10.3 v1.10.4 v1.10.5 v1.10.6 v1.10.7 v1.10.8 v1.11.0 v1.11.1 v1.11.2 v1.11.3 v1.11.5 v1.12.0 v1.12.1 v1.12.2 v1.12.3 v1.12.4 v1.12.5 v1.13.0 v1.13.1 v1.13.2 v1.13.3)
image=$1
image_arch=$2
[[ "$#" -lt 3 ]] && echo 'Usage: $0 --etcd|--cni|<image> <image_arch> version_list' && exit 1;
while [ "$#" -gt 0 ]; do case "$1" in
  --etcd)
    image="etcd"
    etcd_version=$3
    curl -sSL https://github.com/coreos/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-${image_arch}.tar.gz > /tmp/${image}
    break;;
  --cni)
    image="cni"
    cni_version=$3
    curl -sSL https://github.com/containernetworking/plugins/releases/download/${cni_version}/cni-plugins-${image_arch}-${cni_version}.tgz > /tmp/${image}
    break;;
  *)
    printf "%s_checksums:\n" "${image}"
    printf "  %s:\n"  "${image_arch}"
    shift; shift
    for kube_version in ${@}; do
    curl -sSL https://storage.googleapis.com/kubernetes-release/release/${kube_version}/bin/linux/${image_arch}/${image} > /tmp/${image}
    printf "    %s: $(shasum -a 256 /tmp/${image} | cut -d ' ' -f1)\n" "${kube_version}"
    rm /tmp/${image}
    done
    break;;
esac; shift; done

if [[ -f /tmp/${image} ]]; then
  printf "%s_binary_checksums:\n" "${image}"
  printf "  %s: $(shasum -a 256 /tmp/${image} | cut -d ' ' -f1)\n" "${image_arch}"
  rm /tmp/${image}
fi
