# Music production: DAWs, plugin search paths, PipeASIO for Wine/Proton.
{ lib, pkgs, ... }:

let
  pluginFormats = [
    "vst3"
    "clap"
    "lv2"
    "ladspa"
    "dssi"
  ];
in
{
  # Link plugin dirs into the system and per-user profiles, and point DAWs
  # at them (VST3_PATH, CLAP_PATH, ...).
  environment.pathsToLink = map (f: "/lib/${f}") pluginFormats;
  environment.sessionVariables = lib.listToAttrs (
    map (
      f:
      lib.nameValuePair "${lib.toUpper f}_PATH" (
        lib.concatStringsSep ":" [
          "$HOME/.${f}"
          "/etc/profiles/per-user/bitcrushing/lib/${f}"
          "/run/current-system/sw/lib/${f}"
        ]
      )
    ) pluginFormats
  );

  # Function form to get home-manager's lib (lib.hm.dag).
  hm =
    { lib, ... }:
    {
      home.packages = with pkgs; [
        renoise # full version via pkgs/renoise
        plugdata
        audacity
        pipeasio
      ];

      # Wine/Proton only load PipeASIO's unix .so from a path the Proton
      # container can see, which includes $HOME but may not include
      # /nix/store. Copy it under ~/.local/lib/wine on every activation (so
      # changes to pkgs/pipeasio need a switch). Also link PipeWire's lib dir
      # there for LD_PRELOAD: the Steam runtime's libpipewire (0.3.27) lacks
      # pw_data_loop_set_thread_utils.
      home.activation.pipeasioLocalWine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p $HOME/.local/lib/wine/x86_64-unix $HOME/.local/lib/wine/x86_64-windows
        run cp -Lf --no-preserve=mode ${pkgs.pipeasio}/lib/wine/x86_64-unix/* $HOME/.local/lib/wine/x86_64-unix/
        run cp -Lf --no-preserve=mode ${pkgs.pipeasio}/lib/wine/x86_64-windows/* $HOME/.local/lib/wine/x86_64-windows/
        run ln -sfn ${lib.getLib pkgs.pipewire}/lib $HOME/.local/lib/pipewire
      '';
    };
}
