# TODO: maybe just use latest nixpkgs, and not treat warnings as errors?
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/bd85f316bebe290b96b35ddb5c0be62d1f0c9137.tar.gz";
  pkgs = import nixpkgs {
    config = { };
    overlays = [ ];
  };

  packages =
    pkgs: with pkgs; [
      glibc.dev
      linuxHeaders
      gcc.cc
      pkg-config
      gperf
      python3
      cups
      cups.dev
      glib
      gtk3
      google-cloud-sdk
      zlib
      expat
      expat.dev
      nss
      nspr
      krb5
      krb5.dev
      xorg.libX11
      xorg.libX11.dev
      xorg.xorgproto
      xorg.libXcomposite
      xorg.libXcomposite.dev
      xorg.libXdamage
      xorg.libXdamage.dev
      xorg.libXext
      xorg.libXext.dev
      xorg.libXfixes
      xorg.libXfixes.dev
      xorg.libXrandr
      xorg.libXrandr.dev
      xorg.libXtst
      mesa
      dri-pkgconfig-stub
      libgbm
      libva
      libva.dev
      libdrm
      alsa-lib
      alsa-lib.dev
      libxkbcommon
      libxkbcommon.dev
      pango
      dbus
      at-spi2-atk
      xorg.libxcb
      xorg.libxcb.dev
      cairo
      systemd
      xorg.xdpyinfo
      pipewire.dev
      libffi
      libffi.dev
      wayland.dev
      pciutils
      libGL.dev
      xorg.xinput
      xorg.libXrender
      xorg.libXrender.dev
      xorg.libXi
      xorg.libXi.dev
      pulseaudio.dev
      curl.dev
      libuuid
      fontconfig.dev
      vulkan-headers
    ];

  pkgConfigClosure = pkgs.lib.closePropagation (packages pkgs);
  pkgConfigPath =
    pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" pkgConfigClosure
    + ":"
    + pkgs.lib.makeSearchPathOutput "dev" "share/pkgconfig" pkgConfigClosure;

  fhs = pkgs.buildFHSEnv {
    name = "chromium-env";
    targetPkgs = packages;
    profile = ''
      export PKG_CONFIG_PATH=${pkgConfigPath}''${PKG_CONFIG_PATH:+":$PKG_CONFIG_PATH"}
    '';
  };
in
# Return the FHS wrapper. build-cef.sh builds this and re-executes itself as
# `result/bin/chromium-env <script>`, which is the only reliable way to run the
# build inside the FHS namespace (direnv's `use nix` cannot enter it).
#
# For an interactive shell inside the environment use:
#   nix-shell -A env fhs.nix
fhs
