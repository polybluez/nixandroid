{
  lib,
  callPackage,
  buildWad,
  mkAssetsPath,
  doom2df-res,
  executablesAttrs,
  dirtyAssets,
}: let
  wads = lib.listToAttrs (lib.map (wad: {
    name = wad;
    value = callPackage buildWad {
      outName = wad;
      lstPath = "${wad}.lst";
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
    inherit (dirtyAssets) flexui botlist botnames;
  };
in
  lib.mapAttrs (arch: archAttrs: let
    info = archAttrs.infoAttrs.d2dforeverFeaturesSuport;
    executables = let
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
          disable = archAttrs: true;
        };
        headless = {
          enable = archAttrs: info.supportsHeadless;
          disable = archAttrs: true;
        };
        holmes = {
          enable = archAttrs: info.openglDesktop;
          disable = archAttrs: true;
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
              (combo.holmes == "enable" && combo.graphics != "OpenGL2")
              || (combo.holmes == "enable" && combo.io != "SDL2")
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
          x = io;
        in
          if x == "SDL1"
          then {withSDL1 = true;}
          else if x == "SDL2"
          then {withSDL2 = true;}
          else if x == "sysStub"
          then {disableIo = true;}
          else builtins.throw "Unknown build flag";
        graphicsFeature = let
          x = graphics;
        in
          if x == "OpenGL2"
          then {withOpenGL2 = true;}
          else if x == "OpenGLES"
          then {withOpenGLES = true;}
          else if x == "GLStub"
          then {disableGraphics = true;}
          else builtins.throw "Unknown build flag";
        soundFeature = let
          x = sound;
        in
          if x == "FMOD"
          then {withFmod = true;}
          else if x == "SDL_mixer"
          then {withSDL1_mixer = true;}
          else if x == "SDL2_mixer"
          then {withSDL2_mixer = true;}
          else if x == "OpenAL"
          then {withOpenAL = true;}
          else if x == "disable"
          then {disableSound = true;}
          else builtins.throw "Unknown build flag";
        headlessFeature = let
          x = headless;
        in
          if x == "enable"
          then {headless = true;}
          else if x == "disable"
          then {headless = false;}
          else builtins.throw "Unknown build flag";
        holmesFeature = let
          x = holmes;
        in
          if x == "enable"
          then {withHolmes = true;}
          else if x == "disable"
          then {withHolmes = false;}
          else builtins.throw "Unknown build flag";
      in {
        value = doom2d.override ({
            inherit headless;
          }
          // ioFeature
          // graphicsFeature
          // soundFeature
          // headlessFeature
          // holmesFeature);
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
          headlessStr = lib.optionalString (headless == "enable") "-headless";
          holmesStr = lib.optionalString (holmes == "enable") "-holmes";
        in "doom2df-${archAttrs.infoAttrs.name}${ioStr}${soundStr}${graphicsStr}${headlessStr}${holmesStr}";
      };
    in
      {
        lol = archAttrs;
      }
      // (let matrix = featuresMatrix features archAttrs; in lib.listToAttrs (lib.map (x: mkExecutable archAttrs.doom2d x) matrix));
    bundles = {};
  in {
    inherit executables bundles;
  })
  executablesAttrs
