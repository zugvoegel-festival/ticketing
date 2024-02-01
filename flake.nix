{
  description = "Pretix flake configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
  };

  # Use `nix flake show` to view outputs
  outputs = { self, nixpkgs, disko }: {

    # Define modules
    nixosModules = {
      pretix = import ./pretix.nix;
    };

    # Define system configurations
    nixosConfigurations = {
      pretix-server-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          disko.nixosModules.disko
          self.nixosModules.pretix # Import our module
        ];
      };
    };
  };
}
