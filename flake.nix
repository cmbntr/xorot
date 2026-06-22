{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };
  outputs = {nixpkgs, ...}: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
      (system: function nixpkgs.legacyPackages.${system});
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          go-task
          zip
          zig_0_13
          zls_0_14
          alejandra
          git
          rtk
          pass
          fd
          ripgrep
          libarchive
          #flyctl
          #uv ty ruff
          #sqlite
          #corepack
          #deno
          #nodejs
        ];

        shellHook = ''
          echo "Welcome to the xorot development environment!"
          echo "Zig: $(zig version)"
          echo ""
        '';
      };
    });
  };
}
