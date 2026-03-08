{ pkgs }:

file:

builtins.fromJSON (
  builtins.readFile (
    pkgs.runCommand "yaml-to-json" { inherit file; } ''
      ${pkgs.yq-go}/bin/yq eval -o=json "$file" > $out
    ''
  )
)