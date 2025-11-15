{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.terraria-server;
  opt = options.services.terraria-server;
  worldSizeMap = {
    small = 1;
    medium = 2;
    large = 3;
  };

  serverConfig = {
    world = cfg.worldPath;
    autocreate = (builtins.getAttr cfg.autoCreatedWorldSize worldSizeMap);
    maxplayers = cfg.maxPlayers;
    port = cfg.port;
    password = cfg.password;
    motd = cfg.messageOfTheDay;
    banlist = cfg.banListPath;
    secure = if cfg.secure then 1 else 0;
    upnp = if cfg.noUPnP then 0 else 1;
  }
  // cfg.extraSettings;
  serverConfigString = lib.generators.toINIWithGlobalSection { } {
    globalSection = (lib.filterAttrsRecursive (n: v: v != null) serverConfig);
  };
  serverConfigFile = pkgs.writeText "config.ini" serverConfigString;

  tmuxCmd = "${lib.getExe pkgs.tmux} -S ${lib.escapeShellArg cfg.dataDir}/terraria.sock";

  stopScript = pkgs.writeShellScript "terraria-stop" ''
    if ! [ -d "/proc/$1" ]; then
      exit 0
    fi

    lastline=$(${tmuxCmd} capture-pane -p | grep . | tail -n1)

    # If the service is not configured to auto-start a world, it will show the world selection prompt
    # If the last non-empty line on-screen starts with "Choose World", we know the prompt is open
    if [[ "$lastline" =~ ^'Choose World' ]]; then
      # In this case, nothing needs to be saved, so we can kill the process
      ${tmuxCmd} kill-session
    else
      # Otherwise, we send the `exit` command
      ${tmuxCmd} send-keys Enter exit Enter
    fi

    # Wait for the process to stop
    tail --pid="$1" -f /dev/null
  '';
in
{
  options = {
    services.terraria-server = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If enabled, starts a Terraria server. The server can be connected to via `tmux -S ''${config.${opt.dataDir}}/terraria.sock attach`
          for administration by users who are a part of the `terraria` group (use `C-b d` shortcut to detach again).
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 7777;
        description = ''
          Specifies the port to listen on.
        '';
      };

      maxPlayers = lib.mkOption {
        type = lib.types.ints.u8;
        default = 255;
        description = ''
          Sets the max number of players (between 1 and 255).
        '';
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Sets the server password. Leave `null` for no password.
        '';
      };

      messageOfTheDay = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Set the server message of the day text.
        '';
      };

      worldPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          The path to the world file (`.wld`) which should be loaded.
          If no world exists at this path, one will be created with the size
          specified by `autoCreatedWorldSize`.
        '';
      };

      autoCreatedWorldSize = lib.mkOption {
        type = lib.types.enum [
          "small"
          "medium"
          "large"
        ];
        default = "medium";
        description = ''
          Specifies the size of the auto-created world if `worldPath` does not
          point to an existing world.
        '';
      };

      banListPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          The path to the ban list.
        '';
      };

      secure = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Adds additional cheat protection to the server.";
      };

      noUPnP = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disables automatic Universal Plug and Play.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open ports in the firewall";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/terraria";
        example = "/srv/terraria";
        description = "Path to variable state data directory for terraria.";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        example = {
          difficulty = 3;
          journeypermission_godmode = 0;
        };
        description = ''
          Extra game configuration that will go into a config.ini and passed to -config
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.terraria = {
      description = "Terraria server service user";
      group = "terraria";
      home = cfg.dataDir;
      createHome = true;
      uid = config.ids.uids.terraria;
    };

    users.groups.terraria = {
      gid = config.ids.gids.terraria;
    };

    systemd.services.terraria-server = {
      description = "Terraria Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        User = "terraria";
        Group = "terraria";
        Type = "forking";
        GuessMainPID = true;
        UMask = 7;
        ExecStart = "${tmuxCmd} new -d ${pkgs.terraria-server}/bin/TerrariaServer -config ${serverConfigFile}";
        ExecStop = "${stopScript} $MAINPID";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };

  };
}
