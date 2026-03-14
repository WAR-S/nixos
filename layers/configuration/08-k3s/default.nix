{ config, pkgs, lib, infra, ... }:

let
  apIP = infra.network.ap.gateway;
  k3sCfg = infra.k3s;
  k3sPackage = pkgs.k3s_1_32;

  k3sAirgapArchive = pkgs.fetchurl {
    url = k3sCfg.airgap.url;
    sha256 = k3sCfg.airgap.sha256;
  };

  k3sCniNetDir = "/var/lib/rancher/k3s/agent/etc/cni/net.d";

  # Минимальный CNI conflist, чтобы net.d не был пуст при старте containerd (CRI иначе падает с "no network config found").
  minimalFlannelConflist = pkgs.writeText "10-flannel.conflist" ''
    {
      "name": "cbr0",
      "cniVersion": "0.4.0",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": { "portMappings": true }
        }
      ]
    }
  '';

  containerdConfigTemplate = ''
    {{ template "base" . }}

    [plugins."io.containerd.grpc.v1.cri".container_log]
      max_size = "100m"
      max_files = 3
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."insecure-docker-image-name:5000"]
      endpoint = ["http://insecure-docker-image-name:5000"]
  '';
in
{
  system.extraDependencies = [ k3sAirgapArchive ];

  # Каталог CNI до старта k3s; симлинк чтобы /etc/cni/net.d и k3s использовали один путь.
  systemd.tmpfiles.rules = [
    "d ${k3sCniNetDir} 0755 root root -"
  ];

  systemd.services.k3s-cni-dirs = {
    description = "Create CNI dir and symlink for k3s/containerd";
    before = [ "k3s.service" ];
    requiredBy = [ "k3s.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/mkdir -p ${k3sCniNetDir}
      ${pkgs.coreutils}/bin/mkdir -p /etc/cni
      if [ ! -e /etc/cni/net.d ]; then
        ${pkgs.coreutils}/bin/ln -sfn ${k3sCniNetDir} /etc/cni/net.d
      fi
      # Чтобы CRI не падал при пустом net.d, кладём минимальный conflist; k3s при необходимости перезапишет.
      if [ ! -f ${k3sCniNetDir}/10-flannel.conflist ]; then
        ${pkgs.coreutils}/bin/cp -f ${minimalFlannelConflist} ${k3sCniNetDir}/10-flannel.conflist
      fi
    '';
  };

  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPackage;
    containerdConfigTemplate = containerdConfigTemplate;
    nodeName = k3sCfg.nodeName;
    nodeIP = apIP;

    extraFlags = [
      "--node-external-ip=${apIP}"
      "--resolv-conf=/run/systemd/resolve/resolv.conf"
    ];
    disable = [ "traefik" "coredns" ];
  };

  systemd.services.k3s = lib.mkIf config.services.k3s.enable {
    after = [
      "k3s-cni-dirs.service"
      "network-online.target"
      "ntp-sync.service"
      "wifi-ap-wait-ip.service"
    ];
    wants = [
      "network-online.target"
      "ntp-sync.service"
      "wifi-ap-wait-ip.service"
    ];
    requires = [ "wifi-ap-wait-ip.service" "k3s-cni-dirs.service" ];
  };

  services.k3s.autoDeployCharts."ingress-nginx" = {
    repo = "https://kubernetes.github.io/ingress-nginx";
    name = "ingress-nginx";
    version = "4.11.1";
    hash = "sha256-o6yI6vwa8fnRyD1lfHq7oX+LMPlfxuOB+PY2CjAd2dw=";
    values = {
      controller = {
        service = {
          type = "LoadBalancer";
          externalTrafficPolicy = "Local";
        };
        config = {
          "allow-snippet-annotations" = "true";
          "enable-underscores-in-headers" = "true";
        };
      };
    };
  };
}
