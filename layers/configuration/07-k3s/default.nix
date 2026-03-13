{ config, pkgs, lib, ... }:

let
  # IP точки доступа (тот же, что у dnsmasq / NM)
  apIP = "10.10.10.1";
in
{
  #### K3s server, привязанный к 10.10.10.1

  services.k3s = {
    enable = true;
    role = "server"; # используем дефолтный pkgs.k3s без явной версии

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