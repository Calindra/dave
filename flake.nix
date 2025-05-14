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
