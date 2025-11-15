# Terraria Server for NixOS

A Nix flake providing improved Terraria server hosting support for NixOS.

## Features

- NixOS module for easy Terraria server configuration
- Runs in tmux for interactive server administration
- Automatic world creation with configurable sizes
- systemd service integration
- Firewall configuration support
- Configurable server options (port, max players, password, MOTD, etc.)

## Usage

Add this flake to your NixOS configuration:

```nix
{
  inputs.terraria-server.url = "github:Kelwing/terraria-server";

  outputs = { self, nixpkgs, terraria-server }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        terraria-server.nixosModules.default
        {
          services.terraria-server = {
            enable = true;
            port = 7777;
            maxPlayers = 16;
            autoCreatedWorldSize = "large";
          };
        }
      ];
    };
  };
}
```

## Server Administration

Connect to the running server via tmux:

```bash
sudo tmux -S /var/lib/terraria/terraria.sock attach
```

Detach from the session with `Ctrl+b d`.

## Configuration Options

See `terraria.nix:58` for all available configuration options.

## Acknowledgements

This module is based on the [Terraria NixOS module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/games/terraria.nix) from nixpkgs.
