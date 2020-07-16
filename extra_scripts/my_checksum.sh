#!/usr/bin/env bash
declare -a def_list=(v1.11.0 v1.11.1 v1.11.2 v1.11.3 v1.11.5 v1.12.0 v1.12.1 v1.12.2 v1.12.3 v1.12.4 v1.12.5 v1.12.6 v1.13.0 v1.13.1 v1.13.2 v1.13.3 v1.13.4 v1.13.5)
declare -a etcd_def_list=(v3.3.24)
declare -a cni_def_list=(v0.6.0)
declare -a crio_def_list=(v1.13.0)
image=$1
image_arch=$2
[[ "$#" -lt 2 ]] && echo 'Usage: $0 --etcd|--cni|--crio|kubeadm|hyperkube <image_arch>
Usage: $0 --etcd|--cni|--crio|kubeadm|hyperkube <image_arch> version_list<vN.XY.Z vO.W.V.T ...>' && exit 1;
function sort_list() {
  printf '%s
  ' "${@}" | sort -Vr
  return 0
}
function print_checksums() {
  printf "  ${2}: %s #${3} ${1}\n" "$(shasum -a 256 $1 | cut -d ' ' -f1)"
}
while [ "$#" -gt 0 ]; do case "$1" in
  --etcd)
    image="etcd"
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list "${@}")
    else
      version_list=$(sort_list "${etcd_def_list[@]}")
    fi
    printf "%s_binary_checksums:\n" "${image}"
    for etcd_version in "${version_list[@]}"; do
      file="etcd-${etcd_version}-linux-${image_arch}.tar.gz"
      tmpfile="/tmp/${file}"
      curl -sSL https://github.com/coreos/etcd/releases/download/${etcd_version}/$file > $tmpfile
      print_checksums $tmpfile $image_arch $etcd_version
      rm $tmpfile
    done
    break;;
  --cni)
    image="cni"
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list "${@}")
    else
      version_list=$(sort_list "${cni_def_list[@]}")
    fi
    printf "%s_binary_checksums:\n" "${image}"
    for cni_version in "${version_list[@]}"; do
      file="cni-plugins-${image_arch}-${cni_version}.tgz"
      tmpfile="/tmp/${file}"
      curl -sSL https://github.com/containernetworking/plugins/releases/download/${cni_version}/$file > $tmpfile
      print_checksums $tmpfile $image_arch $cni_version
      rm $tmpfile
    done
    break;;
  --crio)
    image="crictl"
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list "${@}")
    else
      version_list=$(sort_list "${crio_def_list[@]}")
    fi
    printf "%s_binary_checksums:\n" "${image}"
    for crio_version in "${version_list[@]}"; do
      file="crictl-${crio_version}-linux-${image_arch}.tar.gz"
      tmpfile="/tmp/${file}"
      curl -sSL https://github.com/kubernetes-sigs/cri-tools/releases/download/${crio_version}/${file} > $tmpfile
      print_checksums $tmpfile $image_arch $crio_version
      rm $tmpfile
    done
    break;;
  *)
    if [[ "$#" -gt 2 ]]; then
      shift; shift
      version_list=$(sort_list "${@}")
    else
      version_list=$(sort_list "${def_list[@]}")
    fi
    printf "%s_checksums:\n" "${image}"
    printf "  %s:\n"  "${image_arch}"
    for kube_version in "${version_list[@]}"; do
      file="${image}"
      tmpfile="/tmp/${file}"
      curl -sSL https://storage.googleapis.com/kubernetes-release/release/${kube_version}/bin/linux/${image_arch}/${file} > $tmpfile
      printf "  %s\n" "$(print_checksums $tmpfile $kube_version $image_arch)"
      rm $tmpfile
    done
    break;;
esac; shift; done
