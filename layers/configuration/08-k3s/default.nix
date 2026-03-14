{ config, pkgs, lib, infra, ... }:

let
  apIP = infra.network.ap.gateway;
  k3sCfg = infra.k3s;
  k3sPackage = pkgs.k3s_1_32;

  # charts из YAML
  charts =
    lib.mapAttrs
      (name: chart: {
        repo = chart.repo;
        name = chart.chart;
        version = chart.version;
        hash = chart.sha256;

        namespace =
          if chart ? namespace
          then chart.namespace
          else "default";

        values =
          if chart ? values
          then chart.values
          else {};
      })
      k3sCfg.charts;

  # airgap images
  airgapImages =
    map
      (img: pkgs.fetchurl {
        url = img.url;
        sha256 = img.sha256;
      })
      k3sCfg.airgapImages;

in
{
  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPackage;

    nodeName = k3sCfg.nodeName;
    nodeIP = apIP;

    extraFlags = [
      "--node-external-ip=${apIP}"
      "--resolv-conf=/run/systemd/resolve/resolv.conf"
      "--kubelet-arg=container-log-max-files=4"
      "--kubelet-arg=container-log-max-size=50Mi"
    ];

    disable = [ "traefik" "coredns"];
    autoDeployCharts = charts;
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


  systemd.tmpfiles.rules =
    map
      (img:
        "L+ /var/lib/rancher/k3s/agent/images/${baseNameOf img} - - - - ${img}")
      airgapImages;
}
