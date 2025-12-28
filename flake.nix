{
  description = "A NixOS flake for my home server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager, used for managing user configuration
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Atomic secret provisioning for NixOS based on sops
    sops-nix.url = "github:Mic92/sops-nix";
    # Not necessary, but pins it to our nixpkgs release
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # nix-bitcoin, for running a bitcoin and lightning node
    nix-bitcoin.url = "github:fort-nix/nix-bitcoin/nixos-25.05";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, sops-nix, nix-bitcoin, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.home-server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-unstable; };
        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit pkgs-unstable; };
            home-manager.users.daniel = import ./home.nix;
          }

          sops-nix.nixosModules.sops

          nix-bitcoin.nixosModules.default
        ];
      };
    };
}
