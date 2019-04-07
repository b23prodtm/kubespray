#!/usr/bin/env bash
declare -a def_list=(v1.10.0-alpha.1 v1.10.0 v1.10.1 v1.10.11 v1.10.2 v1.10.3 v1.10.4 v1.10.5 v1.10.6 v1.10.7 v1.10.8 v1.11.0 v1.11.1 v1.11.2 v1.11.3 v1.11.5 v1.12.0 v1.12.1 v1.12.2 v1.12.3 v1.12.4 v1.12.5 v1.12.6 v1.13.0 v1.13.1 v1.13.2 v1.13.3 v1.13.4)
image=$1
image_arch=$2
[[ "$#" -lt 2 ]] && echo 'Usage: $0 --etcd|--cni|kubeadm|hyperkube <image_arch>
Usage: $0 --etcd|--cni|kubeadm|hyperkube <image_arch> version_list<vN.XY.Z vO.W.V.T ...>' && exit 1;
function sort_list() {
  printf '%s
  ' "${@}" | sort -Vr
  return 0
}
function print_checksums() {
  printf "  ${2}: %s #${3}\n" "$(shasum -a 256 $1 | cut -d ' ' -f1)"
}
while [ "$#" -gt 0 ]; do case "$1" in
  --etcd)
    image="etcd"
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list ${@})
    else
      version_list=$(sort_list ${def_list[@]})
    fi
    printf "%s_binary_checksums:\n" "${image}"
    for etcd_version in ${version_list[@]}; do
      tmpfile="/tmp/${image}-${etcd_version}"
      curl -sSL https://github.com/coreos/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-${image_arch}.tar.gz > $tmpfile
      print_checksums $tmpfile $image_arch $etcd_version
      rm $tmpfile
    done
    break;;
  --cni)
    image="cni"
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list ${@})
    else
      version_list=$(sort_list ${def_list[@]})
    fi
    printf "%s_binary_checksums:\n" "${image}"
    for cni_version in ${version_list[@]}; do
      tmpfile="/tmp/${image}-${cni_version}"
      curl -sSL https://github.com/containernetworking/plugins/releases/download/${cni_version}/cni-plugins-${image_arch}-${cni_version}.tgz > $tmpfile
      print_checksums $tmpfile $image_arch $cni_version
      rm $tmpfile
    done
    break;;
  *)
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list ${@})
    else
      version_list=$(sort_list ${def_list[@]})
    fi
    version_list=$(sort_list ${version_list[@]})
    printf "%s_checksums:\n" "${image}"
    printf "  %s:\n"  "${image_arch}"
    for kube_version in ${version_list[@]}; do
      tmpfile="/tmp/${image}-${kube_version}"
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/${kube_version}/bin/linux/${image_arch}/${image} > $tmpfile
      printf " %s\n" "$(print_checksums $tmpfile $kube_version $image_arch)"
      rm $tmpfile
    done
    break;;
esac; shift; done
