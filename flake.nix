{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    # elm-format is broken on recent nixpkgs: https://github.com/NixOS/nixpkgs/issues/370084
    elm-nixpkgs.url = "github:NixOS/nixpkgs/7e2fb8e0eb807e139d42b05bf8e28da122396bed";
  };

  outputs = {
    self,
    nixpkgs,
    elm-nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
          elm-pkgs = import elm-nixpkgs {inherit system;};
          inherit system;
        });
  in {
    packages = forEachSupportedSystem ({
      pkgs,
      elm-pkgs,
      system,
    }: {
      default = pkgs.buildNpmPackage {
        pname = "elm-decode-runner";
        version = "0.3.0";

        src = ./.;

        npmDepsHash = "sha256-k2hROrbiv+sXiM7tFc6dICgx9PXlcQFgX/TaiqF/noc=";

        # Don't run npm build since this package doesn't have/need a build script
        dontNpmBuild = true;

        nativeBuildInputs = with pkgs; [
          # Need elm compiler at build time since node-elm-compiler uses it
          elm-pkgs.elmPackages.elm
          # Need makeWrapper for the postInstall script
          makeWrapper
        ];

        # Make elm available at runtime since the tool compiles Elm code dynamically
        postInstall = ''
          wrapProgram $out/bin/elm-decode-runner \
            --prefix PATH : ${pkgs.lib.makeBinPath [elm-pkgs.elmPackages.elm]}
        '';

        meta = with pkgs.lib; {
          description = "CLI tool to run an Elm decoder on stdin JSON";
          homepage = "https://github.com/pete-murphy/node-elm-decode-runner";
          license = licenses.isc;
          maintainers = [];
          mainProgram = "elm-decode-runner";
        };
      };
    });

    devShells = forEachSupportedSystem ({
      pkgs,
      elm-pkgs,
      system,
    }: {
      default = pkgs.mkShell {
        buildInputs = [
          # Elm
          elm-pkgs.elmPackages.elm
          elm-pkgs.elmPackages.elm-format
          elm-pkgs.elmPackages.elm-test-rs
          elm-pkgs.elmPackages.elm-json
          elm-pkgs.elmPackages.elm-language-server
          elm-pkgs.elm2nix

          # JS
          pkgs.nodejs_22
          pkgs.typescript

          # Nix
          pkgs.alejandra

          # Scripts
          pkgs.just
          pkgs.bun

          # Testing
          pkgs.bats
        ];
        shellHook = ''
          npm install
          export PATH="$PWD/node_modules/.bin/:$PATH"
        '';
      };
    });
  };
}
