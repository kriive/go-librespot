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
  configFile = format.generate "go-librespot.yaml" cfg.settings;
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
        audio_backend = "alsa";
      };
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "system"
        "user"
      ];
      default = "system";
      description = ''
        How to run the service:
        - "system": Runs as a systemd system service with DynamicUser. Best for headless servers using ALSA.
        - "user": Runs as a systemd user service (per-user). Required for PulseAudio/PipeWire integration on desktops.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.go-librespot.settings = {
      device_name = lib.mkDefault "Go-Librespot";
      device_type = lib.mkDefault "computer";
      bitrate = lib.mkDefault 160;
      initial_volume = lib.mkDefault 100;
      volume_steps = lib.mkDefault 100;
      audio_backend = lib.mkDefault (if cfg.mode == "user" then "pulseaudio" else "alsa");
      zeroconf_enabled = lib.mkDefault true;
    };

    # System Service (DynamicUser)
    systemd.services.go-librespot = lib.mkIf (cfg.mode == "system") {
      description = "Go Librespot - Spotify Connect Receiver";
      after = [
        "network-online.target"
        "sound.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/cp -f ${configFile} \${STATE_DIRECTORY}/config.yaml";
        ExecStart = "${cfg.package}/bin/go-librespot --config_dir \${STATE_DIRECTORY}";
        DynamicUser = true;
        StateDirectory = "go-librespot";
        SupplementaryGroups = [ "audio" ];
        Restart = "on-failure";
        RestartSec = "5s";

        # Fix for os.UserConfigDir() error
        Environment = [ "HOME=/var/lib/go-librespot" ];

        # Security hardening
        CapabilityBoundingSet = "";
        DeviceAllow = [ "/dev/snd rw" ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = false; # Needed for sound
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
      };
    };

    # User Service
    systemd.user.services.go-librespot = lib.mkIf (cfg.mode == "user") {
      description = "Go Librespot - Spotify Connect Receiver";
      after = [
        "network-online.target"
        "sound.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        # Copy config to ~/.config/go-librespot/config.yaml on startup
        ExecStartPre = pkgs.writeShellScript "go-librespot-pre" ''
          mkdir -p %h/.config/go-librespot
          ${pkgs.coreutils}/bin/cp -f ${configFile} %h/.config/go-librespot/config.yaml
        '';
        ExecStart = "${cfg.package}/bin/go-librespot";
        Restart = "on-failure";
        RestartSec = "5s";
        # No DynamicUser or sandboxing needed for user service (runs as user)
      };
    };
  };
}
