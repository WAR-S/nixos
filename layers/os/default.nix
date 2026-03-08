{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./boot.nix
    ./disko-module.nix
    ./users.nix
    ./packages.nix
  ];
}