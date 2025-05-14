{
  description = "Cartesi Dave dev environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/stable";
    foundry.inputs.nixpkgs.follows = "nixpkgs";
    foundry.inputs.flake-utils.follows = "flake-utils";
  };
  outputs = { nixpkgs, flake-utils, foundry, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        foundry-bin = foundry.defaultPackage.${system};
        # Helper to map nix system to debian arch
        debArch = if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "amd64"
                  else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then "arm64"
                  else throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}";
        genext2fsVersion = "1.5.6";
        genext2fs = pkgs.stdenv.mkDerivation {
          pname = "genext2fs";
          version = genext2fsVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/cartesi/genext2fs/releases/download/v${genext2fsVersion}/xgenext2fs_${debArch}.deb";
            sha256 = "sha256-mW5OaKY4tdxZZ9NBD5LsuNL0HjIhi74Pi0xEdNfuvFk=";
          };
          unpackPhase = "true";
          installPhase = ''
            dpkg-deb -x $src $out
            mkdir -p $out/bin/
            ln -s $out/usr/bin/xgenext2fs $out/bin/xgenext2fs
          '';
          nativeBuildInputs = [ pkgs.dpkg ];
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
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
