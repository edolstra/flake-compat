# flake-compat

## Usage

To use, add the following to your `flake.nix`:

```nix
inputs.flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
```

Afterwards, create a `default.nix` file containing the following:

```nix
(import
  (
    let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
    fetchTarball {
      url = lock.nodes.flake-compat.locked.url or "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).defaultNix
```

If you would like a `shell.nix` file, create one containing the above, replacing `defaultNix` with `shellNix`.
