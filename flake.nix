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
    kelwing-homepage.url = "github:Kelwing/kelwing.dev";
    terraria-server.url = "github:Kelwing/terraria-server";
  };

  # Flake outputs
  outputs =
  { self, comin, kelwing-homepage, terraria-server, ... }@inputs:
  let
  # Change this if you're building for a system type other than x86 AMD Linux
  system = "x86_64-linux";
  makeNixosSystem =
  configPath:
  inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs; };
    modules = [
      inputs.determinate.nixosModules.default
      comin.nixosModules.comin
      kelwing-homepage.nixosModules.default
      terraria-server.nixosModules.default
      ({...}: {
        nix.settings = {
          substituters = ["https://lofn.cachix.org"];
          trusted-substituters = ["https://lofn.cachix.org"];
          trusted-public-keys = ["lofn.cachix.org-1:N5d/IDXgSnc4ORB8TpiggU9Wo/VpiWSqrUkE424uBqc="];
        };
      })
      ({...}: {
        services.comin = {
          enable = true;
          remotes = [{
            name = "origin";
            url = "https://github.com/Kelwing/nixos-configs.git";
            branches.main.name = "main";
          }];
        };
      })
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
    formatter.${system} = inputs.nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
  };
}
