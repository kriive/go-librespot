{
  description = "go-librespot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.buildGoModule {
            pname = "go-librespot";
            version = "0.1.0";
            src = ./.;

            # IMPORTANT: When building for the first time, this hash will fail.
            # Nix will display the correct hash in the error message.
            # Copy that hash and replace `pkgs.lib.fakeHash` with it.
            vendorHash = "sha256-ZPdAS/+8aZ6T1+MKi9Aa2dmWRgV++3UuWfBWv6xN+6o=";

            subPackages = [ "cmd/daemon" ];

            nativeBuildInputs = [ pkgs.pkg-config ];

            buildInputs = [
              pkgs.alsa-lib
              pkgs.libvorbis
              pkgs.flac
            ];

            postInstall = ''
              mv $out/bin/daemon $out/bin/go-librespot

              # Create systemd user unit
              mkdir -p $out/lib/systemd/user
              cat > $out/lib/systemd/user/go-librespot.service <<EOF
              [Unit]
              Description=Go Librespot - Spotify Connect Receiver
              Documentation=https://github.com/devgianlu/go-librespot
              After=network-online.target sound.target
              Wants=network-online.target

              [Service]
              ExecStart=$out/bin/go-librespot
              Restart=on-failure
              RestartSec=5

              [Install]
              WantedBy=default.target
              EOF
            '';

            meta = with pkgs.lib; {
              description = "Open Source Spotify Connect Receiver";
              license = licenses.asl20;
              mainProgram = "go-librespot";
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go
              gopls
              gotools
              golangci-lint

              # Build dependencies
              pkg-config
              alsa-lib
              libvorbis
              flac
            ];

            shellHook = ''
              echo "Welcome to go-librespot development shell!"
              echo "Go version: $(go version)"
            '';
          };
        }
      );

      nixosModules.default = import ./nix/module.nix { inherit self; };
    };
}
