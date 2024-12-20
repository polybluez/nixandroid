{
  pkgs,
  lib,
  fpcPkgs,
  ...
}: let
  createCrossPkgSet = abi: abiAttrs: let
    crossTarget = abi;
  in rec {
    gcc = pkgs.pkgsCross.${crossTarget}.buildPackages.wrapCC (pkgs.pkgsCross.${crossTarget}.buildPackages.gcc-unwrapped.override {
      threadsCross = {
        model = "win32";
        package = null;
      };
    });
    stdenvWin32Threads = pkgs.pkgsCross.${crossTarget}.buildPackages.overrideCC pkgs.pkgsCross.${crossTarget}.stdenv gcc;
    enet = (pkgs.pkgsCross.${crossTarget}.enet.override {stdenv = stdenvWin32Threads;}).overrideAttrs (prev: let
      mingwPatchNoUndefined = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/msys2/MINGW-packages/a4bc312869703bda3703fc1cb327fdd7659f0c4b/mingw-w64-enet/001-no-undefined.patch";
        hash = "sha256-t3fXrYG0h2OkZHx13KPKaJL4hGGJKZcN8vdsWza51Hk=";
      };
      mingwPatchWinlibs = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/msys2/MINGW-packages/a4bc312869703bda3703fc1cb327fdd7659f0c4b/mingw-w64-enet/002-win-libs.patch";
        hash = "sha256-vD3sKSU4OVs+zHKuMTNpcZC+LnCyiV/SJqf9G9Vj/cQ=";
      };
    in {
      nativeBuildInputs = [pkgs.pkgsCross.${crossTarget}.buildPackages.autoreconfHook];
      patches = [mingwPatchNoUndefined mingwPatchWinlibs];
      postFixup = ''
        mv $out/bin/libenet-7.dll $out/bin/enet.dll
      '';
    });
    SDL2 = pkgs.pkgsCross.${crossTarget}.SDL2.override {stdenv = stdenvWin32Threads;};
    SDL2_mixer =
      (pkgs.pkgsCross.${crossTarget}.SDL2_mixer.override {
        enableSdltest = false;
        enableSmpegtest = false;
        SDL2 = pkgs.pkgsCross.${crossTarget}.SDL2;
        fluidsynth = null;
        smpeg2 = null;
        flac = null;
        timidity = SDL2;
        stdenv = stdenvWin32Threads;
      })
      .overrideAttrs (prev: {
        buildInputs = prev.buildInputs ++ [pkgs.pkgsCross.${crossTarget}.game-music-emu];
        NIX_CFLAGS_LINK = "-D_WIN32_WINNT=0x0501 -static-libgcc";
        NIX_CFLAGS_COMPILE = "-D_WIN32_WINNT=0x0501 -static-libgcc";
        configureFlags =
          prev.configureFlags
          ++ [
            (lib.enableFeature false "music-flac")
            (lib.enableFeature false "music-gme")
            (lib.enableFeature false "music-gme-shared")
            (lib.enableFeature false "music-midi")
            (lib.enableFeature true "music-mp3")
            (lib.enableFeature true "music-mp3-mpg123")
            (lib.enableFeature true "music-mod")
            (lib.enableFeature false "music-mod-modplug")
            (lib.enableFeature false "music-mod-modplug-shared")
            (lib.enableFeature true "music-mod-xmp")
            (lib.enableFeature false "music-mod-xmp-shared")
          ];
      });
    libmodplug = pkgs.pkgsCross.${crossTarget}.libmodplug;
    libvorbis = pkgs.pkgsCross.${crossTarget}.libvorbis;
    opusfile = pkgs.pkgsCross.${crossTarget}.opusfile;
    libopus = pkgs.pkgsCross.${crossTarget}.libopus;
    mpg123 = pkgs.pkgsCross.${crossTarget}.mpg123;
    libgme = pkgs.pkgsCross.${crossTarget}.game-music-emu;
    wavpack = pkgs.pkgsCross.${crossTarget}.wavpack;
    libxmp = pkgs.pkgsCross.${crossTarget}.libxmp;
    libogg = pkgs.pkgsCross.${crossTarget}.libogg.override {stdenv = stdenvWin32Threads;};
    fmodex = let
      drv = {
        stdenv,
        lib,
        fetchurl,
        p7zip,
      }: let
        version = "4.26.36";
        shortVersion = builtins.replaceStrings ["."] [""] version;
        src = fetchurl {
          url = "https://zdoom.org/files/fmod/fmodapi${shortVersion}win32-installer.exe";
          sha256 = "sha256-jAZP7D9/qt42sn4zz4NwLwc52jH8uQ1roSI0UmqE2aU=";
        };
      in
        stdenv.mkDerivation rec {
          pname = "fmod";
          inherit version shortVersion;

          nativeBuildInputs = [p7zip];

          unpackPhase = false;
          dontUnpack = true;
          dontStrip = true;
          dontPatchELF = true;
          dontBuild = true;

          installPhase = lib.optionalString stdenv.hostPlatform.isLinux ''
            mkdir -p $out/bin
            7z e -aoa ${src}
            cp fmodex.dll $out/bin
          '';

          meta = with lib; {
            description = "Programming library and toolkit for the creation and playback of interactive audio";
            homepage = "http://www.fmod.org/";
            license = licenses.unfreeRedistributable;
            platforms = [
              "i686-mingw32"
            ];
            maintainers = [];
          };
        };
    in
      pkgs.callPackage drv {};
    openal =
      (pkgs.pkgsCross.${crossTarget}.openal.override {
        pipewire = null;
        dbus = null;
        alsa-lib = null;
        libpulseaudio = null;
        stdenv = stdenvWin32Threads;
      })
      .overrideAttrs (prev: {
        /*
        buildInputs =
          prev.buildInputs
          ++ [
            (pkgs.pkgsCross.mingwW64.windows.mcfgthreads)
          ];
        */
        preConfigure = ''
          cmakeFlagsArray+=(
            -DCMAKE_REQUIRED_COMPILER_FLAGS="-D_WIN32_WINNT=0x0501 -static-libgcc -static-libstdc++"
            -DCMAKE_SHARED_LINKER_FLAGS="-D_WIN32_WINNT=0x0501 -static-libgcc -static-libstdc++"
          )
        '';

        postInstall = "";
      });
    #libogg,
    #libvorbis,
    #mpg123,
    lazarus = pkgs.callPackage fpcPkgs.lazarusWrapper {
      fpc = universal.fpc-mingw;
      fpcAttrs = abiAttrs.fpcAttrs;
      lazarus = universal.lazarus-mingw;
    };
  };
  crossPkgs = lib.mapAttrs createCrossPkgSet architectures;
  universal = rec {
    fpc-mingw = pkgs.callPackage fpcPkgs.base {
      archsAttrs = lib.mapAttrs (abi: abiAttrs: abiAttrs.fpcAttrs) architectures;
    };
    lazarus-mingw = pkgs.callPackage fpcPkgs.lazarus {
      fpc-git = fpc-mingw;
    };
  };
  architectures = {
    mingw32 = rec {
      toolchainPrefix = "i686-w64-mingw32";
      fpcAttrs = rec {
        cpuArgs = [""];
        targetArg = "-Twin32";
        basename = "cross386";
        makeArgs = {
          OS_TARGET = "win32";
          CPU_TARGET = "i386";
          CROSSOPT = "\"" + (lib.concatStringsSep " " cpuArgs) + "\"";
        };
        toolchainPaths = [
          "${pkgs.pkgsCross.mingw32.buildPackages.gcc}/bin"
          "${pkgs.writeShellScriptBin "i386-win32-as" "${pkgs.pkgsCross.mingw32.buildPackages.gcc}/bin/${toolchainPrefix}-as $@"}/bin"
          "${pkgs.writeShellScriptBin "i386-win32-ld" "${pkgs.pkgsCross.mingw32.buildPackages.gcc}/bin/${toolchainPrefix}-ld $@"}/bin"
        ];
      };
    };

    # FIXME
    # Doesn't pass install phase with FPC

    /*
    mingwW64 = rec {
      toolchainPrefix = "x86_64-w64-mingw32";
      fpcAttrs = rec {
        cpuArgs = [""];
        targetArg = "-Twin64";
        basename = "cx64";
        makeArgs = {
          OS_TARGET = "win64";
          CPU_TARGET = "x86_64";
          CROSSOPT = "\"" + (lib.concatStringsSep " " cpuArgs) + "\"";
        };
        toolchainPaths = [
          "${pkgs.pkgsCross.mingw32.buildPackages.gcc}/bin"
          "${pkgs.writeShellScriptBin "x86_64-win64-as" "${pkgs.pkgsCross.mingwW64.buildPackages.gcc}/bin/${toolchainPrefix}-as $@"}/bin"
          "${pkgs.writeShellScriptBin "x86_64-win64-ld" "${pkgs.pkgsCross.mingwW64.buildPackages.gcc}/bin/${toolchainPrefix}-ld $@"}/bin"
        ];
      };
    };
    */
  };
in {
  byArch = crossPkgs;
  inherit universal architectures;
}
