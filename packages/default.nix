{
  lib,
  pins,
  writeText,
  stdenv,
  callPackage,
  buildWad,
  mkAssetsPath,
  doom2df-res,
  d2df-editor,
  executablesAttrs,
  mkExecutablePath,
  mkGamePath,
  mkAndroidApk,
  androidRoot,
  androidRes,
  dirtyAssets,
}: let
  wads = lib.listToAttrs (lib.map (wad: {
    name = wad;
    value = callPackage buildWad {
      outName = wad;
      lstPath = "${wad}.lst";
      dfwadCompression = "best";
      inherit doom2df-res;
    };
  }) ["game" "editor" "shrshade" "standart" "doom2d" "doomer"]);
  defaultAssetsPath = mkAssetsPath {
    doom2dWad = wads.doom2d;
    doomerWad = wads.doomer;
    standartWad = wads.standart;
    shrshadeWad = wads.shrshade;
    gameWad = wads.game;
    editorWad = wads.editor;
    editorLangRu = "${d2df-editor}/lang/editor.ru_RU.lng";
    extraRoots = let
      mkTxtFile = name': txt:
        stdenv.mkDerivation {
          name = lib.replaceStrings [" "] ["_"] name';

          src = null;
          phases = ["installPhase"];

          installPhase = ''
            mkdir $out
            cp ${writeText "${name'}" txt} "$out/${name'}"
          '';
        };
      findMoreContentTxt = mkTxtFile "Get MORE game content HERE.txt" ''
        Дополнительные уровни и модели игрока можно скачать на https://doom2d.org
        You can download additional maps or user skins on our website: https://doom2d.org
      '';
    in [findMoreContentTxt];
    inherit (dirtyAssets) flexuiWad botlist botnames;
  };
  createBundlesAndExecutables = lib.mapAttrs (arch: archAttrs: let
    info = archAttrs.infoAttrs.d2dforeverFeaturesSuport;

    features = {
      io = {
        SDL1 = archAttrs: archAttrs ? "SDL1";
        SDL2 = archAttrs: archAttrs ? "SDL2";
        sysStub = archAttrs: info.supportsHeadless;
      };
      graphics = {
        OpenGL2 = archAttrs: info.openglDesktop;
        OpenGLES = archAttrs: info.openglEs;
        GLStub = archAttrs: info.supportsHeadless;
      };
      sound = {
        FMOD = archAttrs: archAttrs ? "fmodex";
        SDL_mixer = archAttrs: archAttrs ? "SDL_mixer";
        SDL2_mixer = archAttrs: archAttrs ? "SDL2_mixer";
        OpenAL = archAttrs: archAttrs ? "openal";
        NoSound = archAttrs: true;
      };
      headless = {
        Enable = archAttrs: info.supportsHeadless;
        Disable = archAttrs: true;
      };
      holmes = {
        Enable = archAttrs: info.openglDesktop;
        Disable = archAttrs: true;
      };
    };
    featuresMatrix = features: archAttrs: let
      prepopulatedFeatureAttrs = lib.mapAttrs (featureName: featureAttrs: (lib.mapAttrs (definition: value: (value archAttrs) == true)) featureAttrs) features;
      filteredFeatureAttrs = lib.mapAttrs (featureName: featureAttrs: (lib.filterAttrs (definition: value: value == true) featureAttrs)) prepopulatedFeatureAttrs;
      zippedFeaturesWithPossibleValues = lib.mapAttrs (feature: featureAttrset: (lib.foldlAttrs (acc: definitionName: definitionValue: acc ++ [definitionName]) [] featureAttrset)) filteredFeatureAttrs;
      featureCombinations = lib.cartesianProduct zippedFeaturesWithPossibleValues;
    in
      # TODO
      # Get some filters here.
      # Maybe sound == SDL2 && io != SDL2?
      lib.filter (
        combo:
          !(
            (combo.holmes == "Enable" && combo.graphics != "OpenGL2")
            || (combo.holmes == "Enable" && combo.io != "SDL2")
            #|| (combo.io == "sysStub" && combo.headless == "disable")
            #|| (combo.sound == "SDL2_mixer" && combo.io != "SDL2")
            #|| (combo.sound == "SDL" && combo.io != "SDL2")
          )
      )
      featureCombinations;
    mkExecutable = doom2d: featureAttrs @ {
      graphics,
      headless,
      io,
      sound,
      holmes,
    }: let
      ioFeature = let
        table = {
          "SDL1" = {withSDL1 = true;};
          "SDL2" = {withSDL2 = true;};
          "sysStub" = {disableIo = true;};
        };
      in
        table.${io};
      graphicsFeature = let
        table = {
          "OpenGL2" = {withOpenGL2 = true;};
          "OpenGLES" = {withOpenGLES = true;};
          "GLStub" = {disableGraphics = true;};
        };
      in
        table.${graphics};
      soundFeature = let
        table = {
          "FMOD" = {withFmod = true;};
          "SDL_mixer" = {withSDL1_mixer = true;};
          "SDL2_mixer" = {withSDL2_mixer = true;};
          "OpenAL" = {withOpenAL = true;};
          "NoSound" = {disableSound = true;};
        };
      in
        table."${sound}";
      boolFeature = flag: x:
        if x == "Enable"
        then {"${flag}" = true;}
        else {"${flag}" = false;};
      headlessFeature = boolFeature "headless" headless;
      holmesFeature = boolFeature "holmes" holmes;
    in {
      value = {
        drv = doom2d.override ({
            inherit headless;
            buildAsLibrary = info.loadedAsLibrary;
          }
          // ioFeature
          // graphicsFeature
          // soundFeature
          // headlessFeature
          // holmesFeature);
        defines = {
          inherit graphics headless sound holmes io;
        };
        pretty = "Doom2D Forever for ${archAttrs.infoAttrs.pretty}: ${io}, ${sound}, ${graphics}${lib.optionalString (holmes == "Enable") ", with Holmes"}${lib.optionalString (headless == "Enable") ", headless"}";
      };
      name = let
        soundStr =
          if sound == "disable"
          then "-NoSound"
          else "-${sound}";
        ioStr =
          if io == "sysStub"
          then "-IOStub"
          else "-${io}";
        graphicsStr = "-${graphics}";
        headlessStr = lib.optionalString (headless == "Enable") "-headless";
        holmesStr = lib.optionalString (holmes == "Enable") "-holmes";
      in "doom2df-${archAttrs.infoAttrs.name}${ioStr}${soundStr}${graphicsStr}${headlessStr}${holmesStr}";
    };
    matrix = featuresMatrix features archAttrs;
    allCombos = lib.listToAttrs (lib.map (x: mkExecutable archAttrs.doom2d x) matrix);
    defaultExecutable = ((builtins.head (lib.attrValues (lib.filterAttrs (n: v: v.defines == archAttrs.infoAttrs.bundle) allCombos))).drv).override {
      withMiniupnpc = true;
      inherit (archAttrs) miniupnpc;
    };
    executables = allCombos;
    bundles = lib.recursiveUpdate {} (lib.optionalAttrs (!info.loadedAsLibrary) {
      default = callPackage mkGamePath {
        gameExecutablePath = callPackage mkExecutablePath rec {
          byArchPkgsAttrs = {
            "${arch}" = {
              sharedLibraries = lib.map (drv: drv.out) defaultExecutable.buildInputs;
              doom2df = defaultExecutable;
              editor = archAttrs.editor;
              isWindows = archAttrs.infoAttrs.isWindows;
              asLibrary = info.loadedAsLibrary;
              prefix = ".";
            };
          };
        };
        gameAssetsPath = defaultAssetsPath;
      };
    });
  in {
    __archPkgs = archAttrs;
    inherit defaultExecutable executables bundles;
  });
in
  (createBundlesAndExecutables executablesAttrs)
  // {
    android = let
      # FIXME
      # Just find something with "android" as prefix instead of hardcoding it
      sdk = executablesAttrs.android-arm64-v8a.androidSdk;
      sdl = executablesAttrs.android-arm64-v8a.SDL2;
      gameExecutablePath = callPackage mkExecutablePath {
        byArchPkgsAttrs =
          lib.mapAttrs (arch: archAttrs: let
            doom2d = archAttrs.doom2d.override {
              withSDL2 = true;
              withSDL2_mixer = true;
              withVorbis = true;
              withFluidsynth = true;
              withLibXmp = true;
              withMpg123 = true;
              withOpus = true;
              withGme = true;
              withOpenGLES = true;
              buildAsLibrary = true;
            };
          in {
            sharedLibraries = lib.map (drv: drv.out) doom2d.buildInputs;
            # FIXME
            # Android version is hardcoded
            doom2df = doom2d;
            isWindows = false;
            asLibrary = true;
            editor = null;
            prefix = "${archAttrs.infoAttrs.androidAbi}";
          })
          (lib.filterAttrs (n: v: lib.hasPrefix "android" n) executablesAttrs);
      };
    in {
      bundles = {
        inherit gameExecutablePath;
        default = mkAndroidApk {
          androidSdk = sdk;
          SDL2ForJava = sdl;
          gameAssetsPath = defaultAssetsPath;
          inherit androidRoot androidRes gameExecutablePath;
        };
      };
      executables = {};
    };
  }
