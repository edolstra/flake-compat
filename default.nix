# Compatability function to allow flakes to be used by
# non-flake-enabled Nix versions. Given a source tree containing a
# 'flake.nix' and 'flake.lock' file, it fetches the flake inputs and
# calls the flake's 'outputs' function. It then returns an attrset
# containing 'defaultNix' (to be used in 'default.nix'), 'shellNix'
# (to be used in 'shell.nix').

{ src, system ? builtins.currentSystem or "unknown-system" }:

let

  lockFilePath = src + "/flake.lock";

  lockFile = builtins.fromJSON (builtins.readFile lockFilePath);

  fetchTree =
    { info, locked, ... }:
    if locked.type == "github" then
      {
        outPath = fetchTarball {
          url = "https://api.github.com/repos/${locked.owner}/${locked.repo}/tarball/${locked.rev}";
          sha256 = info.narHash;
        };
        rev = locked.rev;
        shortRev = builtins.substring 0 7 locked.rev;
        lastModified = info.lastModified;
        lastModifiedDate = formatSecondsSinceEpoch info.lastModified;
        narHash = info.narHash;
        __toString = self: self.outPath;
      }
    else if locked.type == "git" then
      { outPath =
          builtins.fetchGit
            ({ url = locked.url; }
             // (if locked ? rev then { inherit (locked) rev; } else {})
             // (if locked ? ref then { inherit (locked) ref; } else {})
            );
        rev = locked.rev;
        shortRev = builtins.substring 0 7 locked.rev;
        lastModified = info.lastModified;
        lastModifiedDate = formatSecondsSinceEpoch info.lastModified;
        narHash = info.narHash;
        __toString = self: self.outPath;
      }
    else
      # FIXME: add Mercurial, tarball inputs.
      throw "flake input has unsupported input type '${locked.type}'";

  callFlake4 = flakeSrc: locks:
    let
      flake = import (flakeSrc + "/flake.nix");

      inputs = builtins.mapAttrs (n: v:
        if v.flake or true
        then callFlake4 (fetchTree v) v.inputs
        else fetchTree v) locks;

      outputs = flakeSrc // (flake.outputs (inputs // {self = outputs;}));
    in
      assert flake.edition == 201909;
      outputs;

  src' =
    (if src ? outPath then src else { outPath = src; })
    // { lastModified = 0; lastModifiedDate = formatSecondsSinceEpoch 0; };

  # Format number of seconds in the Unix epoch as %Y%m%d%H%M%S.
  formatSecondsSinceEpoch = t:
    let
      rem = x: y: x - x / y * y;
      days = t / 86400;
      secondsInDay = rem t 86400;
      hours = secondsInDay / 3600;
      minutes = (rem secondsInDay 3600) / 60;
      seconds = rem t 60;

      # Courtesy of https://stackoverflow.com/a/32158604.
      z = days + 719468;
      era = (if z >= 0 then z else z - 146096) / 146097;
      doe = z - era * 146097;
      yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
      y = yoe + era * 400;
      doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
      mp = (5 * doy + 2) / 153;
      d = doy - (153 * mp + 2) / 5 + 1;
      m = mp + (if mp < 10 then 3 else -9);
      y' = y + (if m <= 2 then 1 else 0);

      pad = s: if builtins.stringLength s < 2 then "0" + s else s;
    in "${toString y'}${pad (toString m)}${pad (toString d)}${pad (toString hours)}${pad (toString minutes)}${pad (toString seconds)}";

  allNodes =
    builtins.mapAttrs
      (key: node:
        let
          sourceInfo = if key == lockFile.root then src' else fetchTree { info = node.info; locked = (removeAttrs node.locked ["dir"]); };
          subdir = if key == lockFile.root then "" else node.locked.dir or "";
          flake = import (sourceInfo + (if subdir != "" then "/" else "") + subdir + "/flake.nix");
          inputs = builtins.mapAttrs (inputName: key: allNodes.${key}) (node.inputs or {});
          outputs = flake.outputs (inputs // { self = result; });
          result = outputs // sourceInfo // { inherit inputs; inherit outputs; inherit sourceInfo; };
        in
          if node.flake or true then
            assert builtins.isFunction flake.outputs;
            result
          else
            sourceInfo
      )
      lockFile.nodes;

  result =
    if lockFile.version == 4
    then callFlake4 src' (lockFile.inputs)
    else if lockFile.version == 5
    then allNodes.${lockFile.root}
    else throw "lock file '${lockFilePath}' has unsupported version ${toString lockFile.version}";

in
result
