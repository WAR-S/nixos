#!/usr/bin/env bash

set -e

echo "Creating NixOS infrastructure repository structure..."

mkdir -p repo

cd repo

mkdir -p \
systems/edge-node \
systems/dev-node \
\
layers/hardware \
layers/os \
layers/network \
layers/security \
layers/platform \
layers/applications \
\
modules/vpn \
modules/wifi \
modules/dns \
modules/k3s \
\
config \
lib \
images \
ci

touch \
flake.nix \
flake.lock \
README.md

touch \
systems/edge-node/default.nix \
systems/edge-node/hardware.nix \
systems/dev-node/default.nix

touch \
layers/hardware/default.nix \
layers/hardware/udev.nix \
layers/hardware/modem.nix \
layers/hardware/wifi-device.nix

touch \
layers/os/default.nix \
layers/os/base.nix \
layers/os/users.nix \
layers/os/packages.nix \
layers/os/boot.nix

touch \
layers/network/default.nix \
layers/network/wifi-ap.nix \
layers/network/dnsmasq.nix \
layers/network/routing.nix

touch \
layers/security/default.nix \
layers/security/vpn.nix \
layers/security/firewall.nix \
layers/security/secrets.nix

touch \
layers/platform/default.nix \
layers/platform/k3s.nix \
layers/platform/runtime.nix

touch \
layers/applications/default.nix \
layers/applications/argocd.nix \
layers/applications/repos.nix

touch \
modules/vpn/openvpn.nix \
modules/wifi/access-point.nix \
modules/dns/dnsmasq.nix \
modules/k3s/k3s-cluster.nix

touch \
config/infrastructure.yaml \
config/secrets.yaml

touch \
lib/yaml-loader.nix \
lib/helpers.nix

touch \
images/iso.nix \
images/qcow.nix

touch \
ci/build-image.nix \
ci/pipeline.yaml

echo "Repository structure created successfully."