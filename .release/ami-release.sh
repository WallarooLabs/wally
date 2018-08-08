#!/bin/bash
set -eu
rc_branch_name=$1
for_version=$2

build_metrics_binary() {
  curl -L -o Wallaroo_Metrics_UI-0.5.3-x86_64.AppImage 'https://wallaroo-labs.bintray.com/wallaroolabs-ftp/wallaroo/0.5.3/Wallaroo_Metrics_UI-0.5.3-x86_64.AppImage'
  chmod +x Wallaroo_Metrics_UI-0.5.3-x86_64.AppImage
  ./Wallaroo_Metrics_UI-0.5.3-x86_64.AppImage --appimage-extract
  rm Wallaroo_Metrics_UI-0.5.3-x86_64.AppImage
  mv squashfs-root metrics_ui
  sed -i 's/sleep 4/sleep 0/' metrics_ui/AppRun
  rm -rf .release/metrics_ui
  mv metrics_ui .release/
  (cd .release/metrics_ui && ln -s AppRun metrics_reporter_ui)
  (cd .release && zip -r metrics_ui.zip metrics_ui && rm -rf metrics_ui)
}

compile_for_sandy_bridge() {
  PREV_HEAD=$(git rev-parse --abbrev-ref HEAD)
  TARGET_CPU=sandybridge
  PONYC_OPTS='target_cpu=${TARGET_CPU}'
  git checkout "$rc_branch_name"
  make clean
  (make build-machida "$PONYC_OPTS")
  (cd utils/data_receiver && make "$PONYC_OPTS")
  (cd utils/cluster_shutdown && make "$PONYC_OPTS")
  (cd utils/cluster_shrinker && make "$PONYC_OPTS")
  (cd giles/sender && make "$PONYC_OPTS")

  zip -j9 .release/wallaroo_bin.zip \
      machida/build/machida \
      utils/data_receiver/data_receiver \
      utils/cluster_shutdown/cluster_shutdown \
      utils/cluster_shrinker/cluster_shrinker \
      giles/sender/sender
  echo "------ Wallaroo binaries compiled for ${TARGET_CPU}"
  git checkout "$PREV_HEAD"
}



build_ami_with_packer() {
  (cd .release &&
    regions=$(echo -n "$(cat ami/regions)" | tr '\n' ',')
    for cmd in validate build; do
      packer ${cmd} \
         -var "ami_regions=${regions}" \
         -var "wallaroo_version=${for_version}" \
         ami/template.json
    done
  )
}

build_metrics_binary
compile_for_sandy_bridge
build_ami_with_packer
