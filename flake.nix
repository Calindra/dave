{
  description = "A basic flake with a shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    foundry.url = "github:shazow/foundry.nix/monthly"; # Use monthly branch for permanent releases
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
          overlays = [
            foundry.overlay
          ];
        };
        # stdenv = pkgs.stdenv;
        # lib = nixpkgs.lib;
      in
      {
        formatter = pkgs.nixfmt-rfc-style;
        devShells.default = pkgs.mkShell {
          # Point bindgen to where the clang library would be
          # LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          # BINDGEN_EXTRA_CLANG_ARGS = ''
          #   ${stdenv.cc}/nix-support/libc-crt1-cflags \
          #   ${stdenv.cc}/nix-support/libc-cflags \
          #   ${stdenv.cc}/nix-support/cc-cflags \
          #   ${stdenv.cc}/nix-support/libcxx-cxxflags \
          #   ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
          #   ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config}"}
          # '';
          packages = with pkgs; [
            include-what-you-use
            bashInteractive
            foundry-bin
            just
            rustc
            cargo
            clippy
            boost
            jq
            rustfmt
            openssl
            pkgconf
            libclang
            clang-tools
          ];
        };
      }
    );
}
