argsOuter@{...}:
let
  # specifying args defaults in this slightly non-standard way to allow us to include the default values in `args`
  args = rec {
    pkgs = import <nixpkgs> {};
    localOverridesPath = ./local.nix;
  } // argsOuter;
  ourTerraform = let
    pkgs = args.pkgs;
    version = "0.12.19";  # when changing, MUST also update the srcSha256 at the same time
    srcSha256 = "067gzxysz8r2myj3rh0vwrs0pmbgb21jxlmawlf4v0lkjnhj6kwv";
  in if
    (pkgs.lib.fileContents ./.terraform-version) != version then throw "requested terraform version doesn't match that in .terraform-version. please update it here."
  else (pkgs.terraform_0_12.overrideAttrs (oldAttrs: {
    name = "terraform-${version}";
    src = pkgs.fetchFromGitHub {
      owner = "hashicorp";
      repo = "terraform";
      rev = "v${version}";
      sha256 = srcSha256;
    };
  })).withPlugins (p: [ p.pass ]);
in (with args; {

  prometheusAWSConfigBetaEnv = (pkgs.stdenv.mkDerivation rec {
    name = "prom-aws-config-beta-env";
    shortName = "promaws";
    buildInputs = with pkgs; [ gitFull cacert ourTerraform jq ];

    LD_LIBRARY_PATH = "${pkgs.stdenv.lib.makeLibraryPath buildInputs}";
    LANG="en_GB.UTF-8";

    shellHook = ''
      export PS1="\[\e[0;36m\](nix-shell\[\e[0m\]:\[\e[0;36m\]${shortName})\[\e[0;32m\]\u@\h\[\e[0m\]:\[\e[0m\]\[\e[0;36m\]\w\[\e[0m\]\$ "
    '';
  }).overrideAttrs (if builtins.pathExists localOverridesPath then (import localOverridesPath args) else (x: x));
})

