{
  description = "Pretix flake configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    bank-automation.url = "github:zugvoegel-festival/pretix-bank-automation";

    # Partitioning
    disko.url = "github:nix-community/disko";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Use `nix flake show` to view outputs
  outputs = { self, nixpkgs, disko, sops-nix, bank-automation }@inputs:
    let
      # Systems used to run deploy.sh (orchestrator, not pretix-server-01 target).
      deploySystems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      packages = nixpkgs.lib.genAttrs deploySystems (
        system: {
          nixos-rebuild = nixpkgs.legacyPackages.${system}.nixos-rebuild;
        }
      );
      apps = nixpkgs.lib.genAttrs deploySystems (
        system: {
          nixos-rebuild = {
            type = "app";
            program = "${packages.${system}.nixos-rebuild}/bin/nixos-rebuild";
          };
        }
      );
    in
    {
      inherit packages apps;

    # Output all modules in ./modules to flake. Modules should be in
    # individual subdirectories and contain a default.nix file
    nixosModules = builtins.listToAttrs (map
      (x: {
        name = x;
        value = import (./modules + "/${x}");
      })
      (builtins.attrNames (
        nixpkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./modules)
      )));
    # Define system configurations

    nixosConfigurations = {
      pretix-server-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          ./environments/pretix.nix
          ./environments/schwarmplaner-prod.nix
          ./environments/schwarmplaner-test.nix
          ./environments/99trees-prod.nix
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          { imports = builtins.attrValues self.nixosModules; }
        ];
      };
    };
    };
}
