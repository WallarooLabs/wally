{  use_pinned ? true }:

let buffy = import ./default.nix { use_pinned = use_pinned; };
in
  with buffy;
  with buffy.pkgs;
  let
      ansible-frozen = stdenv.lib.overrideDerivation ansible2 (oldAttrs: rec {
        version = "2.1.1.0";
        name = "ansible-${version}";

        src = fetchurl {
          url = "http://releases.ansible.com/ansible/${name}.tar.gz";
          sha256 = "12v7smivjz8d2skk5qxl83nmkxqxypjm8b7ld40sjfwj4g0kkrv1";
        };

      });
      python27Env = python.buildEnv.override { 
                   extraLibs = [ pythonPackages.boto
                                 ansible-frozen
                                 pythonPackages.paramiko
                                 pythonPackages.packet-python ];
                   ignoreCollisions = true;
                 };
      python35Env = python35.buildEnv.override { 
                   extraLibs = [ python3Packages.click
                                 ];
                 };
      terraform-frozen = stdenv.lib.overrideDerivation terraform (oldAttrs: rec {
        version = "0.7.4";
        rev = "v${version}";

        src = fetchFromGitHub {
          inherit rev;
          owner = "hashicorp";
          repo = "terraform";
          sha256 = "1mj9kk9awhfv717xf9d8nc35xva8wqhbgls7cbgycg550cc2hf85";
        };

      });
  in


  lib.overrideDerivation buffy (attrs: {
    buildInputs = [
      python27Env
      python35Env
      terraform-frozen
      ansible-frozen
      vim
      jq
      vagrant
      openssh
    ] ++ stdenv.lib.optionals (!stdenv.isDarwin) [
      virtualbox
    ] ++ attrs.buildInputs;
  })


