{
  description = "A basic flake with a shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    foundry.url = "github:shazow/foundry.nix/stable";
    naersk.url = "github:nix-community/naersk/master";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      naersk,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        naersk-lib = pkgs.callPackage naersk { };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;
        defaultPackage = naersk-lib.buildPackage ./.;
        devShells.default = pkgs.mkShell {
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
          LIBCLANG_PATH = "${pkgs.llvmPackages_19.libclang.lib}/lib";
          # Add glibc, clang, glib and other headers to bindgen search path
          BINDGEN_EXTRA_CLANG_ARGS =
            # Includes with normal include path
            (builtins.map (a: ''-I"${a}/include"'') [
              # add dev libraries here (e.g. pkgs.libvmi.dev)
              pkgs.glibc.dev
            ]) # Includes with special directory paths
            ++ [
              ''-I"${pkgs.llvmPackages_19.libclang.lib}/lib/clang/19/include"''
              ''-I"${pkgs.glib.dev}/include/glib-2.0"''
              ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
            ];

          packages = with pkgs; [
            bashInteractive
            just
            rustc
            cargo
            clippy
            just
            unixtools.xxd
            boost
            pkg-config
            openssl
            llvmPackages_19.libclang
            glibc
          ];
        };
      }
    );
}
