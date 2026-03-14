{ config, pkgs, lib, infra, ... }:

let
  apIP = infra.network.ap.gateway;
  k3sCfg = infra.k3s;
  k3sPackage = pkgs.k3s_1_32;

  k3sAirgapArchive = pkgs.fetchurl {
    url = k3sCfg.airgap.url;
    sha256 = k3sCfg.airgap.sha256;
  };

  # Кастомный шаблон отключён: секция container_log ломала CRI (unknown service runtime.v1.RuntimeService).
  # Зеркало реестра и лимиты логов можно добавить позже в формате для твоей версии containerd.
  # containerdConfigTemplate = null;  # по умолчанию — дефолтный конфиг k3s
in
{
  system.extraDependencies = [ k3sAirgapArchive ];

  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPackage;
    # Не задаём containerdConfigTemplate — используем дефолт, иначе CRI не поднимается.

  containerdConfigTemplate = pkgs.writeText "k3s-containerd-config.toml.tmpl" ''
    {{ template "base" . }}

    [plugins."io.containerd.grpc.v1.cri".container_log]
      max_size = "100m"
      max_files = 3
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."insecure-docker-image-name:5000"]
      endpoint = ["http://insecure-docker-image-name:5000"]
  '';

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
