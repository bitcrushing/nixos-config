# nixpkgs' renoise builds the demo unless given the full release tarball,
# which can't be downloaded without a licence. Look for it in installers/.
{
  lib,
  stdenv,
  renoise,
}:

let
  inherit (renoise) version;
  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64";
  expected = "rns_${lib.replaceStrings [ "." ] [ "" ] version}_linux_${arch}.tar.gz";
  candidates = [
    (../../installers + "/${expected}")
    (../../installers + "/rns_${lib.replaceStrings [ "." ] [ "_" ] version}_linux_${arch}.tar.gz")
  ];
  installer = lib.findFirst builtins.pathExists null candidates;
in
if installer == null then
  throw ''
    nixpkgs updated Renoise to ${version}, but installers/${expected} is missing.
    Download the Linux installer from https://backstage.renoise.com, put it in
    ~/nixos/installers/, then make it visible to the flake (intent-to-add only;
    never commit it, a pre-commit hook guards this) with:
      git add -N -f installers/${expected}
  ''
else
  renoise.override { releasePath = installer; }
