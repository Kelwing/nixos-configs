{
  description = "my server nixos configurations";

  # Flake inputs
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # Stable Nixpkgs (use 0.1 for unstable)
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3"; # Determinate 3.*
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kelwing-homepage.url = "github:Kelwing/kelwing.dev";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    scibot.url = "github:StarCross-Industries/scibot";
    impostor.url = "github:Kelwing/impostor-flake";
    launcher.url = "github:Kelwing/AmongUsLauncherAPI";
  };

  # Flake outputs
  outputs =
    {
      self,
      comin,
      kelwing-homepage,
      nixpkgs,
      flake-utils,
      agenix,
      scibot,
      impostor,
      launcher,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      makeNixosSystem =
        configPath:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            inputs.determinate.nixosModules.default
            kelwing-homepage.nixosModules.default
            scibot.nixosModules.default
            impostor.nixosModules.default
            agenix.nixosModules.default
            launcher.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                impostor.overlays.default
                scibot.overlays.default
              ];
            }
            configPath
          ];
        };
    in
    {
      nixosConfigurations.vidar = makeNixosSystem ./hosts/vidar/configuration.nix;
      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter.${system} = inputs.nixpkgs.legacyPackages.${system}.nixfmt;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            agenix.packages.${system}.default
            nixfmt-rfc-style
            nil
            nixd
          ];
        };
        packages = {
          vidar = self.nixosConfigurations.vidar.config.system.build.toplevel;
          inherit (pkgs) terraria-server;
        };
      }
    );
}
