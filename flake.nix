{
  description = "my server nixos configurations";

  nixConfig = {
    extra-substituters = [
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3"; # Determinate 3.*
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
    srvos.url = "github:nix-community/srvos";
  };

  # Flake outputs
  outputs =
    {
      self,
      kelwing-homepage,
      nixpkgs,
      flake-utils,
      agenix,
      scibot,
      impostor,
      launcher,
      home-manager,
      srvos,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      makeNixosSystem =
        configPath:
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs factorioLib;
          };
          modules = [
            srvos.nixosModules.server
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
                self.overlays.terraria-server
              ];
            }
            configPath
          ];
        };
      factorioLib = inputs.nixpkgs.legacyPackages.${system}.callPackage ./lib/factorio { };
    in
    {
      nixosConfigurations.vidar = makeNixosSystem ./hosts/vidar/configuration.nix;
      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter.${system} = inputs.nixpkgs.legacyPackages.${system}.nixfmt;
      overlays.terraria-server = final: prev: {
        terraria-server = prev.terraria-server.overrideAttrs (
          finalAttrs: previousAttrs: rec {
            version = "1.4.5.5";
            urlVersion = prev.lib.replaceStrings [ "." ] [ "" ] version;
            src = prev.fetchurl {
              url = "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${urlVersion}.zip";
              sha256 = "sha256-BmLT5ATBviSfYuc3Cx/aMHUNTBs6S56GHJF8YIJXhtU=";
            };
            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp -r Linux $out/
              chmod +x "$out/Linux/TerrariaServer.bin.x86_64"
              ln -s "$out/Linux/TerrariaServer.bin.x86_64" $out/bin/TerrariaServer

              # use our own SDL3 library
              rm $out/Linux/lib64/libSDL3.so.0
              ln -s ${prev.lib.getLib prev.sdl3}/lib/libSDL3.so.0 $out/Linux/lib64/libSDL3.so.0

              runHook postInstall
            '';
          }
        );
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.terraria-server ];
        };
        factorio-mods = pkgs.callPackage ./pkgs/factorio-mods { };
        pythonEnv = pkgs.python3.withPackages (ps: [
          ps.virtualenv
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            agenix.packages.${system}.default
            nixfmt-rfc-style
            nil
            nixd
            factorio-mods
            ruff
            ty
            pythonEnv
          ];
        };
        packages = {
          vidar = self.nixosConfigurations.vidar.config.system.build.toplevel;
          vidarVm = self.nixosConfigurations.vidar.config.system.build.vm;
          inherit (pkgs) terraria-server;
        };
      }
    );
}
