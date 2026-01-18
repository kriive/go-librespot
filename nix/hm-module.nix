{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.go-librespot;
  format = pkgs.formats.yaml { };
in
{
  options.services.go-librespot = {
    enable = lib.mkEnableOption "go-librespot";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.default;
      description = "The go-librespot package to use.";
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        Configuration for go-librespot.
        See https://github.com/devgianlu/go-librespot for available options.
      '';
      example = {
        device_name = "My Speaker";
        bitrate = 320;
        audio_backend = "pulseaudio";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.go-librespot.settings = {
      device_name = lib.mkDefault "Go-Librespot";
      device_type = lib.mkDefault "computer";
      bitrate = lib.mkDefault 160;
      initial_volume = lib.mkDefault 100;
      volume_steps = lib.mkDefault 100;
      audio_backend = lib.mkDefault "pulseaudio";
      zeroconf_enabled = lib.mkDefault true;
    };

    # Write configuration file using XDG standard
    xdg.configFile."go-librespot/config.yaml".source = format.generate "go-librespot.yaml" cfg.settings;

    systemd.user.services.go-librespot = {
      Unit = {
        Description = "Go Librespot - Spotify Connect Receiver";
        After = [
          "network-online.target"
          "sound.target"
        ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/go-librespot"; # Config is automatically loaded from XDG path
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
