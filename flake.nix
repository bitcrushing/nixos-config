{
  description = "nixPC system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode-upstream.url = "github:anomalyco/opencode";
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = { self, nixpkgs, opencode-upstream, ghostty, ... }@inputs:
    let
      system = "x86_64-linux";

      opencode-patched = opencode-upstream.packages.${system}.default.overrideAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          if [ -f packages/script/src/index.ts ]; then
            substituteInPlace packages/script/src/index.ts \
              --replace-fail "if (!semver.satisfies(process.versions.bun, expectedBunVersionRange))" "if (false)"
          fi
        '';
      });

    in {
      nixosConfigurations.nixPC = nixpkgs.lib.nixosSystem {
        
        inherit system;
        specialArgs = { inherit inputs; };

        modules = [
          ./configuration.nix
          
          {
            nixpkgs.overlays = [
            ( final: prev: {
              opencode = opencode-patched;
              ghostty = ghostty.packages.${system}.default;
            }
            )
          ];
        }
      ];
    };
  };
}
