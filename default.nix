let
  _nixpkgs = import <nixpkgs> { };
  _pinned_nixpkgs = (import
            ( _nixpkgs.fetchFromGitHub
              { owner = "Sendence";
                repo = "nixpkgs";
                rev = "a42d05c50c09817f838d8630b35bb611962d6f7d";
                sha256 = "13n58ynrk24x9hdwwwmn0qk3qidlhrp8ch5r7q2lpd3zzd42fhza";
              }
            ) { });
in
{  use_pinned ? true }:

let
  pkgs = if use_pinned then _pinned_nixpkgs else _nixpkgs;
  requiredVersion = "1.11.4";
  x = if ! builtins ? nixVersion || builtins.compareVersions requiredVersion builtins.nixVersion != 0 then
    abort "This version of Nixpkgs requires Nix == ${requiredVersion}, your version is ${builtins.nixVersion} please upgrade or downgrade!"
  else
    "";
  fg = args: pkgs.fetchFromGitHub {
       owner = args.owner;
       repo = args.repo;
       rev = args.rev;

       # Dummy hash
       sha256 = builtins.hashString "sha256" args.rev;
     };
  latestGit = args: pkgs.stdenv.lib.overrideDerivation (fg args) (old: {
              outputHash     = null;
              outputHashAlgo = null;
              outputHashMode = null;
              sha256         = null;
            });
in
  with pkgs;
  with beamPackages;

### compilers available ###
#        gcc49
#        gcc5
#        gcc6
#        clang_37
#        clang_38
#        clang_39
### llvm versions available ###
#        llvm_37
#        llvm_38
#        llvm_39
#
  let ponyc-lto = ponyc.override { lto = true; llvm = llvm_38; /* cc = clang39; */ };
      sendence-ponyc = stdenv.lib.overrideDerivation ponyc-lto (oldAttrs: rec {
      name = "sendence-ponyc-${version}";
      version = "sendence-13.4.1";
      src  = latestGit {
               owner  = "sendence";
               repo   = "ponyc";
               rev    = version;
             };
      patches = [ ];
    });
      hex-13 = stdenv.lib.overrideDerivation beamPackages.hex (oldAttrs: rec {
        version = "v0.13.2";
 
        src = fetchFromGitHub {
            owner = "hexpm";
            repo = "hex";
            rev = version;
            sha256 = "075fln8w7vdcp3xgypda06d4hjmai9a68y7h55463z9nrjwgscp5";
        };
    });
      nodejs-447 = stdenv.lib.overrideDerivation nodejs (oldAttrs: rec {
        version = "4.4.7";
        src = fetchurl {
          url = "http://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
          sha256 = "0cgpzpdlpqmyfm0w7jfbana6rwvzssllfcis8dy63yrzrfwh1y8y";
        };
   });
      pony-stable-frozen = stdenv.lib.overrideDerivation pony-stable (oldAttrs: {
      name = "pony-stable-frozen";
      src  = latestGit {
               owner  = "jemc";
               repo   = "pony-stable";
               rev    = "f1f7977dc6ad6b6c66071725a7f54d28ee52048c";
             };
    });
#    monhub = buildMix ({
#            name = "monhub";
#            version = "0.0.1";
#            src = ./.;
#            beamDeps  = [ hex erlware_commons_0_21_0 gproc_0_5_0 phoenix_1_1_6 phoenix_html_2_6_2 phoenix_live_reload_1_0_5 gettext_0_11_0 cowboy_1_0_4 exrm_1_0_5 ];
#            buildPhase = ''echo nobuild'';
#            installPhase = ''echo noinstall'';
#
#            meta = {
#              longDescription = ''monhub.'';
#            };
#      shellHook = ''
#        export PS1="\n\[\033[1;32m\][buffy-dev:\w]$\[\033[0m\] "
#        eval "$configurePhase"
#        mv _build/prod/lib monitoring_hub/deps
#        rm -r _build
#      '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
#        export LC_ALL=en_US.utf8
#        export LANG=en_US.utf8
#      '' + stdenv.lib.optionalString stdenv.isDarwin ''
#        export LC_ALL=en_US.UTF-8
#        export LANG=en_US.UTF-8
#        export SSL_CERT_FILE=$HOME/.nix-profile/etc/ssl/certs/ca-bundle.crt
#      '';
#          });
    osxApps = stdenv.mkDerivation {
      name = "osx-app-deps-impure";

      phases = [ "installPhase" ];

      dockerVersion = "1.12.1";
      vboxVersion = "5.0.20r106931";

      installPhase = ''
        mkdir -p $out/bin

        if [ -e /usr/local/bin/docker ]; then
          ln -s /usr/local/bin/docker $out/bin/docker
          myDockerVersion=$($out/bin/docker --version | head -n 1 | sed -e 's/Docker version //' | sed -e 's/, build.*//')

#          if [ "$dockerVersion" != "$myDockerVersion" ]; then
#            echo "docker version ($myDockerVersion) not correct. Please install $dockerVersion!"
#            exit 1
#          fi
        fi

        if [ -e /sbin/ifconfig ]; then
          ln -s /sbin/ifconfig $out/bin/ifconfig
        fi

        if [ -e /usr/bin/getconf ]; then
          ln -s /usr/bin/getconf $out/bin/getconf
        fi

        if [ -e /usr/local/bin/VBoxManage ]; then
          ln -s /usr/local/bin/VBoxManage $out/bin/VBoxManage
          myVboxVersion="$($out/bin/VBoxManage --version)"

#          if [ "$vboxVersion" != "$myVboxVersion" ]; then
#            echo "VirtualBox version ($myVboxVersion) not correct. Please install $vboxVersion!"
#            exit 1
#          fi
        fi

      '';

    };
  in
#    monhub

    stdenv.mkDerivation {
      name = "buffy";

      preUnpack = stdenv.lib.optionalString (!stdenv.isDarwin) ''
        export LC_ALL=en_US.utf8
        export LANG=en_US.utf8
      '' + stdenv.lib.optionalString stdenv.isDarwin ''
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
      '';

      buildInputs = [
        sendence-ponyc
        pony-stable-frozen
        file
        man
        makeWrapper
        git
        which
        curl
        awscli
#        python
#        python3
#        python3Packages.click
#        monhub
        elixir
        rebar
        rebar3-open
        hex-13
        nodePackages.npm
        nodejs-447
#        beamPackages.erlware_commons_0_21_0
#        beamPackages.gproc_0_5_0
#        beamPackages.phoenix_1_1_6
#        beamPackages.phoenix_html_2_6_2
#        beamPackages.phoenix_live_reload_1_0_5
#        beamPackages.gettext_0_11_0
#        beamPackages.cowboy_1_0_4
#        beamPackages.exrm_1_0_5
      ] ++ stdenv.lib.optionals stdenv.isDarwin [ 
        osxApps
        darwin.ps
#        darwin.network_cmds
      ] ++ stdenv.lib.optionals (!stdenv.isDarwin) [
        procps
        nettools
        docker
      ];

      passthru = { pkgs = pkgs; };

      shellHook = ''
        export PYTHONHOME=$(dirname $(dirname $(which python)))
        export PS1="\n\[\033[1;32m\][buffy-dev:\w]$\[\033[0m\] "
      '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
        export LC_ALL=en_US.utf8
        export LANG=en_US.utf8
      '' + stdenv.lib.optionalString stdenv.isDarwin ''
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        export SSL_CERT_FILE=$HOME/.nix-profile/etc/ssl/certs/ca-bundle.crt
      '';
    }


