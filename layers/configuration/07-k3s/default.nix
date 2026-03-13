{ config, pkgs, lib, ... }:

let
  # IP точки доступа (тот же, что у dnsmasq / NM)
  apIP = "10.10.10.1";

  # Версию k3s можно менять здесь: "1_29", "1_30", и т.д.
  k3sVersion = "1_30";

  k3sPackage =
    let
      attr = "k3s_${k3sVersion}";
    in
      if builtins.hasAttr attr pkgs
      then builtins.getAttr attr pkgs
      else pkgs.k3s; # fallback на дефолтный k3s, если конкретной версии нет
in
{
  #### K3s server, привязанный к 10.10.10.1

  services.k3s = {
    enable = true;
    role = "server";
    package = k3sPackage;

    nodeName = "k3s-node";
    nodeIP   = apIP;

    # Как в твоём юните: --node-ip / --node-external-ip / resolv.conf
    extraFlags = [
      "--node-external-ip=${apIP}"
      "--resolv-conf=/run/systemd/resolve/resolv.conf"
    ];

    # Отключаем traefik и coredns, как у тебя
    disable = [ "traefik" "coredns" ];
  };

  #### Порядок запуска: после сети, NTP и Wi‑Fi AP (10.10.10.1 уже висит)

  systemd.services.k3s = lib.mkIf config.services.k3s.enable {
    after = [
      "network-online.target"
      "ntp-sync.service"         # твой кастомный sync из 01-ntp
      "wifi-ap-wait-ip.service"  # из 05-wifi-ap: ждёт inet 10.10.10.1/24 на wlp2s0
    ];
    wants = [
      "network-online.target"
      "ntp-sync.service"
      "wifi-ap-wait-ip.service"
    ];
    requires = [
      "wifi-ap-wait-ip.service"
    ];
  };

  #### Ingress NGINX через встроенный Helm-контроллер k3s

  # Это создаст helm-чарт ingress-nginx с:
  # - Service type=LoadBalancer на 80/443
  # - externalTrafficPolicy=Local
  # - ConfigMap с allow-snippet-annotations / enable-underscores-in-headers
  services.k3s.autoDeployCharts."ingress-nginx" = {
    repo = "https://kubernetes.github.io/ingress-nginx";
    name = "ingress-nginx";
    # Поставь нужную версию чарта (пример):
    version = "4.11.1";

    # Значения helm-чарта — то, что ты сейчас делаешь руками kubectl apply/patch
    values = {
      controller = {
        service = {
          type = "LoadBalancer";
          externalTrafficPolicy = "Local";
          # Обычно k3s servicelb сам пробрасывает на nodeIP=10.10.10.1.
          # Если захочешь жёстко прописать:
          # loadBalancerIP = apIP;
        };

        # Это попадает в ConfigMap ingress-nginx-controller
        config = {
          "allow-snippet-annotations"       = "true";
          "enable-underscores-in-headers"   = "true";
        };
      };
    };
  };
}