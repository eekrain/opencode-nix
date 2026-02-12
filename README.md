# opencode-nix

Nix flake for [OpenCode](https://github.com/anomalyco/opencode) and Kilo Code CLI.

**Features:**
- Direct binary packaging for OpenCode and Kilo Code CLI
- Smart Home Manager detection with automatic symlink management
- Pre-built binaries via Garnix for instant installation
- Hourly automated updates for both packages
- Linux and macOS support (x86_64 and aarch64)

## Quick Start

**Run OpenCode without installing:**
```bash
nix run github:eekrain/opencode-nix#opencode
```

**Run Kilo Code CLI without installing:**
```bash
nix run github:eekrain/opencode-nix#kilocode
```

**Install both to your profile:**
```bash
nix profile add github:eekrain/opencode-nix#opencode
nix profile add github:eekrain/opencode-nix#kilocode
```

## Binary Cache

This flake uses [Garnix](https://garnix.io) for CI and binary caching. The `nixConfig` in `flake.nix` automatically configures the cache, so pre-built binaries are fetched without any manual setup.

If prompted to allow configuration from the flake, answer yes or add `accept-flake-config = true` to your Nix configuration.

## Flake Usage

### As a Flake Input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode-nix.url = "github:eekrain/opencode-nix";
  };

  outputs = { self, nixpkgs, opencode-nix, ... }: {
    # Your configuration here
  };
}
```

### NixOS Configuration

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.opencode-nix.packages.${pkgs.system}.opencode
    inputs.opencode-nix.packages.${pkgs.system}.kilocode
  ];
}
```

### Home Manager Configuration

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.opencode-nix.packages.${pkgs.system}.opencode
    inputs.opencode-nix.packages.${pkgs.system}.kilocode
  ];
}
```

### Using the Overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode-nix.url = "github:eekrain/opencode-nix";
  };

  outputs = { self, nixpkgs, opencode-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ opencode-nix.overlays.default ];
      };
    in {
      # pkgs.opencode and pkgs.kilocode are now available
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.opencode pkgs.kilocode ];
      };
    };
}
```

## Home Manager Integration

This package includes smart Home Manager detection. When Home Manager is detected, the package skips creating symlinks to respect your declarative configuration.

**Detection methods:**
- `HM_SESSION_VARS` environment variable is set
- `~/.config/home-manager` directory exists
- `/etc/profiles/per-user/$USER` directory exists

**Behavior:**
- **Home Manager detected:** Skips symlink creation and cleans up any orphaned symlinks
- **Home Manager absent:** Creates `~/.local/bin/opencode` symlink for convenience

**Automatic cleanup:** If you previously installed opencode standalone (creating a `~/.local/bin/opencode` symlink) and later enable Home Manager, the package will automatically remove the orphaned symlink on first run to prevent PATH conflicts.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENCODE_NIX_VERBOSE` | Set to `1` to enable Home Manager detection and symlink management messages |

Example:
```bash
export OPENCODE_NIX_VERBOSE=1
```

## Updating

**If using `nix profile add`:**
```bash
nix profile upgrade '.*opencode.*'
nix profile upgrade '.*kilocode.*'
```

**If using as a flake input:**
```bash
nix flake update opencode-nix
nixos-rebuild switch  # or home-manager switch
```

## Contributing

### Development Setup

```bash
git clone https://github.com/eekrain/opencode-nix
cd opencode-nix
nix develop  # enters shell with dev tools
nix build .#opencode
nix build .#kilocode
./result/bin/opencode --version
```

### Update Workflow

OpenCode updates use `update.sh` (updates `version.json`):

```bash
# Enter dev shell (provides required tools)
nix develop

# Check for updates (dry run)
./update.sh

# Update to latest version
./update.sh --update
```

The script:
1. Queries GitHub API for the latest non-prerelease release
2. Compares against current version in `version.json`
3. With `--update`: fetches SRI hashes for all platforms and updates `version.json`

Kilo Code CLI updates use `update-kilocode.sh` (updates `kilocode-version.json`):

```bash
# Enter dev shell (provides required tools)
nix develop

# Check for updates (dry run)
./update-kilocode.sh

# Update to latest version
./update-kilocode.sh --update
```

### Automated Updates

A GitHub Actions workflow runs hourly to check for new releases. When a new version is found, it automatically:
1. Updates `version.json` and/or `kilocode-version.json`
2. Validates with `nix flake check`
3. Pushes directly to main

## License

This packaging is MIT-licensed. See `LICENSE`.

OpenCode is developed by [Anomaly](https://github.com/anomalyco).
