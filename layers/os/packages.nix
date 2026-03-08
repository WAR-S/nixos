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
  ];
}