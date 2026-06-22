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
          zig_0_16
          zls_0_16
          alejandra
          git
          rtk
          pass
          fd
          ripgrep
          zip
          libarchive
          bun
          nodejs
        ];

        shellHook = ''
          echo "Welcome to the xorot development environment!"
          echo "zig: $(zig version)"
          echo "zls: $(zls version)"
          echo ""
        '';
      };
    });
  };
}
