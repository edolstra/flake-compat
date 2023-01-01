# flake-compat

## Usage

To use, add the following to your `flake.nix`:

```nix
inputs.flake-compat = {
  url = "github:edolstra/flake-compat";
  flake = false;
};
```

Afterwards, create a `default.nix` file containing the following:

```nix
(import
  (
    let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
    fetchTarball {
      url = with lock.nodes.flake-compat.locked;
        "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).defaultNix
```

If you would like a `shell.nix` file, create one containing the above, replacing `defaultNix` with `shellNix`.
