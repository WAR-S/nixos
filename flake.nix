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

    # Путь к nixpkgs для импорта модулей установщика
    nixpkgsPath = pkgs.path;
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

    # Конфигурация для сборки установочного ISO: минимальный образ + пакеты + самоустановка + сжатие
    nixosConfigurations.iso =
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit infra;
          # Путь к исходникам флейка для копирования в ISO (самоустановка)
          flakeSrc = self.outPath or self;
          diskoPackage = disko.packages.${system}.default;
        };
        modules = [
          "${nixpkgsPath}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          "${nixpkgsPath}/nixos/modules/installer/cd-dvd/channel.nix"
          ./layers/os/packages.nix
          ./layers/os/users.nix
          ./systems/iso/auto-install.nix
        ];
      };

    # Сборка: nix build .#iso
    packages.${system}.iso =
      self.nixosConfigurations.iso.config.system.build.isoImage;

    # Сборка ISO и вывод пути к образу (удобно после сборки сразу видеть путь)
    apps.${system}.iso-build = {
      type = "app";
      program = toString (pkgs.writeShellScript "iso-build" ''
        set -e
        export PATH="${pkgs.lib.makeBinPath [ pkgs.nix pkgs.coreutils ]}:$PATH"
        nix build .#iso "$@"
        echo ""
        echo "Путь к образу:"
        if [[ -d result/iso ]]; then
          for f in result/iso/*.iso; do
            [[ -e "$f" ]] && echo "  $(realpath "$f")" && break
          done
          ls -la result/iso/
        else
          echo "  $(realpath result)/iso/"
        fi
      '');
    };
  };
}