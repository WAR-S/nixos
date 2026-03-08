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

    apps.${system} = {
      disko = {
        type = "app";
        program = "${disko.packages.${system}.default}/bin/disko";
      };
      iso-build = {
        type = "app";
        program = toString (pkgs.writeShellScript "iso-build" ''
          set -e
          export PATH="${pkgs.lib.makeBinPath [ pkgs.nix pkgs.coreutils ]}:$PATH"
          OUT="$(nix build .#iso --print-out-paths --no-link "$@" | head -1)"
          if [[ -d "$OUT" ]]; then
            for f in "$OUT"/*.iso; do
              if [[ -e "$f" ]]; then
                cp -f "$f" ./"$(basename "$f")"
                echo ""
                echo "Образ скопирован в текущую директорию:"
                echo "  $(realpath "./$(basename "$f")")"
                ls -la "./$(basename "$f")"
                exit 0
              fi
            done
          fi
          echo "ISO не найден в $OUT"
          exit 1
        '');
      };
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

    # Сборка: nix build .#iso — result указывает на каталог с одним файлом .iso (без вложенного iso/)
    packages.${system}.iso = pkgs.runCommand "nixos-nettop-iso" {
      src = self.nixosConfigurations.iso.config.system.build.isoImage;
    } ''
      mkdir -p $out
      cp "$src/iso/"*.iso $out/
    '';

  };
}