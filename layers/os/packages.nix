{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    openssh
    jq
    yq
    neofetch
    dmidecode
    hostname
    openvpn
    # Debug network lscpu lscpi
    pciutils
    # Wi‑Fi AP (05-wifi-ap): hostapd, dnsmasq, iw
    networkmanager
    dnsmasq
    iw
    # удобно отлаживать профили
    nmcli
  ];
}