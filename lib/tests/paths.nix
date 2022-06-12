{ lib       ? ( builtins.getFlake ( toString ../.. ) ).lib
, withDrv   ? false
, nixpkgs   ? builtins.getFlake "nixpkgs"
, system    ? builtins.currentSystem
, pkgs      ? nixpkgs.legacyPackages.${system}
, writeText ? pkgs.writeText
}:
let
  inherit (lib) libdbg libpath;

  tests = with libpath; {

    testIsCoercibleToPath = {
      expr = map isCoercibleToPath ["" ./.];
      expected = [true true];
    };

  };  # End tests

  harness = libdbg.mkTestHarness ( {
    inherit writeText tests;
    env = { inherit lib system nixpkgs pkgs; };
  } // ( if withDrv then { inherit writeText; } else {} ) );

in harness
