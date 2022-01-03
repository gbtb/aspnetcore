{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    makeShell.url = "github:ursi/nix-make-shell";
  };

  outputs = { self, nixpkgs, makeShell, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      make-shell = import makeShell { pkgs = pkgs; system = "x86_64-linux"; };
      rpath = pkgs.lib.makeLibraryPath (with pkgs; [
        stdenv.cc.cc
        zlib
        curl
        icu
        libunwind
        libuuid
        openssl
      ] ++ lib.optionals stdenv.isLinux [
        lttng-ust_2_12
      ]);
    in
    {

      defaultPackage.x86_64-linux = pkgs.stdenv.mkDerivation {
        name = "aspnetcore-dev";
        src = ./.;
        buildPhase = ''
          export DOTNET_CLI_TELEMETRY_OPTOUT=1
          patchShebangs ./eng/common
           source ./eng/common/tools.sh 
           InitializeToolset
        '';
        buildInputs = [ pkgs.curl ];
      };
      devShell.x86_64-linux = pkgs.mkShell
        {

          pkgs = with pkgs; [
            nodejs-16_x
            curl
            #jdk
            #(with dotnetCorePackages; combinePackages [ dotnet-sdk_6 ])
            #dotnet-sdk_3
            #dotnet-sdk_5
          ];
          shellHook = ''
            echo `pwd`
            out=".dotnet"
            export DOTNET_CLI_TELEMETRY_OPTOUT=1

            patchShebangs ./eng/common
            source ./eng/common/tools.sh 
            #InitializeToolset &

            patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" $out/dotnet
            patchelf --set-rpath "${rpath}" $out/dotnet
            find $out -type f -name "*.so" -exec patchelf --set-rpath '$ORIGIN:${rpath}' {} \;
            find $out -type f \( -name "apphost" -or -name "createdump" \) -exec patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" --set-rpath '$ORIGIN:${rpath}' {} \;
            ./restore.sh
          '';
        };
    };
}
