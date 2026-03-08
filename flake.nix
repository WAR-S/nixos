{
  description = "Minimal edge NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko }:

  let
    system = "x86_64-linux";

    pkgs = import nixpkgs { inherit system; };

    yamlLoader = import ./lib/yaml-loader.nix { inherit pkgs; };

    infra = yamlLoader ./config/infrastructure.yaml;
  in {

    apps.${system}.disko = {
      type = "app";
      program = "${disko.packages.${system}.default}/bin/disko";
    };

    nixosConfigurations.edge-node =
      nixpkgs.lib.nixosSystem {

        inherit system;

        specialArgs = {
          infra = infra;
        };

        modules = [
          disko.nixosModules.disko
          ./systems/edge-node
          ./layers/os
        ];
      };
  };
}