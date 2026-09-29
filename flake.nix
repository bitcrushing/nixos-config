{
  description = "PC system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      stylix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.PC = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };

        modules = [
          ./configuration.nix
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager
          (
            { lib, ... }:
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              # Rename unmanaged files that are in the way instead of failing.
              home-manager.backupFileExtension = "hm-backup";
              # Modules write `hm.<option>` instead of
              # `home-manager.users.bitcrushing.<option>`.
              imports = [ (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" "bitcrushing" ]) ];
            }
          )
        ];
      };

      # `nix fmt` formats every .nix file except the generated hardware config.
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree.override {
        settings.formatter.nixfmt.excludes = [ "hardware-configuration.nix" ];
      };
    };
}
