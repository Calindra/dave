{
  description = "Cartesi Dave dev environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/stable";
    foundry.inputs.nixpkgs.follows = "nixpkgs";
    foundry.inputs.flake-utils.follows = "flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      foundry,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        foundry-bin = foundry.defaultPackage.${system};
        # Helper to map nix system to debian arch
        debArch =
          if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
            "amd64"
          else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
            "arm64"
          else
            throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}";
        genext2fs =
          let
            genext2fsVersion = "1.5.6";
            genext2fsHash =
              if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
                "sha256-mW5OaKY4tdxZZ9NBD5LsuNL0HjIhi74Pi0xEdNfuvFk="
              else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
                "sha256-5ayoEWS3YrvlRHus70Hk+p41f9nI9E5RnFIGIn1DFE0="
              else
                throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}";
          in
          pkgs.stdenv.mkDerivation {
            pname = "genext2fs";
            version = genext2fsVersion;
            src = pkgs.fetchurl {
              url = "https://github.com/cartesi/genext2fs/releases/download/v${genext2fsVersion}/xgenext2fs_${debArch}.deb";
              sha256 = genext2fsHash;
            };
            unpackPhase = "true";
            installPhase = ''
              dpkg-deb -x $src $out
              mkdir -p $out/bin/
              ln -s $out/usr/bin/xgenext2fs $out/bin/xgenext2fs
            '';
            nativeBuildInputs = [ pkgs.dpkg ];
          };
        machineEmulator =
          let
            machineEmulatorVersion = "0.19.0-alpha4";
            machineHash =
              if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
                "sha256-wYwHi8QuX9uxNmkS0N2ZFz3pZSJYBYlHjZbb0PiqSL8="
              else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
                "sha256-vBnSl9SMS4aENIb4sKmY1G8FNzoRuPqWrY8An7du29I="
              else
                throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}";
          in
          pkgs.stdenv.mkDerivation {
            pname = "machine-emulator";
            version = machineEmulatorVersion;
            src = pkgs.fetchurl {
              url = "https://github.com/cartesi/machine-emulator/releases/download/v${machineEmulatorVersion}/machine-emulator_${debArch}.deb";
              sha256 = machineHash;
            };
            unpackPhase = "true";
            installPhase = ''
              dpkg-deb -x $src $out
              mkdir -p $out/bin/
              ln -s $out/usr/bin/cartesi-machine $out/bin/cartesi-machine
            '';
            nativeBuildInputs = [ pkgs.dpkg ];
          };
      in
      {
        formatter = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            docker
            docker-buildx
            docker-compose
            rustc
            cargo
            rustfmt
            clippy
            just
            foundry-bin
            gcc
            gnumake
            git
            wget
            curl
            lua5_4
            libslirp
            libclang
            boost181
            unixtools.xxd
            jq
            sqlite
            unzip
            pkg-config
            luarocks
            lcov
            procps
            openssl
            stdenv.cc
            gcc12
            gcc12Stdenv
            # gcc-cross-aarch64
            genext2fs
            machineEmulator
          ];
          shellHook = ''
            export SVM_ROOT="$PWD/.svm"
            export CARGO_HOME="$PWD/.cargo"
            export RUSTUP_HOME="$PWD/.rustup"
            export PATH="$PWD/.cargo/bin:$PATH"
            export PATH="$PWD/.svm/bin:$PATH"
            export PATH="$PWD/.foundry/bin:$PATH"
            export DEBIAN_FRONTEND=noninteractive

            docker run --privileged --rm tonistiigi/binfmt --install riscv64
          '';
        };
      }
    );
}
