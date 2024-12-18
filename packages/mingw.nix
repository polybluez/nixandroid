{
  default = {
    pkgs,
    lib,
    fpcPkgs,
    d2dfPkgs,
    mkZipBundle,
    gameAssetsPath,
  }: let
    mingwPkgs = import ../cross/mingw {
      inherit pkgs lib;
      inherit fpcPkgs d2dfPkgs;
    };
    byArchAdditional =
      lib.mapAttrs (target: targetAttrs: let
        doom2df-zip = mkZipBundle {
          inherit gameAssetsPath;
          unknownPkgsAttrs = {
            sharedBundledLibraries = [targetAttrs.enet targetAttrs.SDL2 targetAttrs.fmodex];
            doom2df = targetAttrs.doom2d;
          };
          isWindows = true;
        };
      in {
        inherit doom2df-zip;
      })
      mingwPkgs.byArch;
  in
    lib.recursiveUpdate mingwPkgs {byArch = byArchAdditional;};

  # Maybe WIN95 support or something...
  /*
  old = ...;
  */
}
