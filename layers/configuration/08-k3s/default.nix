{ config, pkgs, lib, infra, ... }:

let
  apIP = infra.network.ap.gateway;
  k3sCfg = infra.k3s;
  k3sPackage = pkgs.k3s_1_32;

  # Файл кладём вручную через tmpfiles, не через services.k3s.containerdConfigTemplate.
  containerdConfigFile = pkgs.writeText "k3s-containerd-config.toml.tmpl" ''
    {{ template "base" . }}

    [plugins."io.containerd.grpc.v1.cri".container_log]
      max_size = "100m"
      max_files = 3

    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."insecure-docker-image-name:5000"]
      endpoint = ["http://insecure-docker-image-name:5000"]
  '';

  containerdConfigPath = "/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl";
in
{
  # Файл config.toml.tmpl в каталог k3s (симлинк на store).
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher/k3s/agent/etc/containerd 0755 root root -"
    "L+ ${containerdConfigPath} - - - - ${containerdConfigFile}"
  ];

  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPackage;

    nodeName = k3sCfg.nodeName;
    nodeIP = apIP;

    extraFlags = [
      "--node-external-ip=${apIP}"
      "--resolv-conf=/run/systemd/resolve/resolv.conf"
    ];

    disable = [ "traefik" "coredns"];
  };

  systemd.services.k3s = lib.mkIf config.services.k3s.enable {
    after = [
      "network-online.target"
      "ntp-sync.service"
      "wifi-ap-wait-ip.service"
    ];
    wants = [
      "network-online.target"
      "ntp-sync.service"
      "wifi-ap-wait-ip.service"
    ];
    requires = [ "wifi-ap-wait-ip.service" ];
  };

  services.k3s.autoDeployCharts."ingress-nginx" = {
    repo = "https://kubernetes.github.io/ingress-nginx";
    name = "ingress-nginx";
    version = "4.11.1";
    hash = "sha256-o6yI6vwa8fnRyD1lfHq7oX+LMPlfxuOB+PY2CjAd2dw=";
    values = {
      controller = {
        hostNetwork = true;
        dnsPolicy = "ClusterFirstWithHostNet";
        service = {
          enabled = false;
        };
        config = {
          "allow-snippet-annotations" = "true";
          "enable-underscores-in-headers" = "true";
        };
      };
    };
  };


}
