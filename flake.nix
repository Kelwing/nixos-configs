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
    in
    {
      nixosConfigurations.vidar = makeNixosSystem ./hosts/vidar/configuration.nix;
      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter.${system} = inputs.nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
      overlays.terraria-server = final: prev: {
        terraria-server = prev.terraria-server.overrideAttrs (
          finalAttrs: previousAttrs: rec {
            version = "1.4.5.3";
            urlVersion = prev.lib.replaceStrings [ "." ] [ "" ] version;
            src = prev.fetchurl {
              url = "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${urlVersion}.zip";
              sha256 = "sha256-5W6XpGaWQTs9lSy1UJq60YR6mfvb3LTts9ppK05XNCg=";
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
        };
      }
    );
}
