# TODO: maybe just use latest nixpkgs, and not treat warnings as errors?
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/bd85f316bebe290b96b35ddb5c0be62d1f0c9137.tar.gz";
  pkgs = import nixpkgs {
    config = { };
    overlays = [ ];
  };
in
pkgs.buildFHSEnv {
  name = "chromium-env";

  extraOutputsToInstall = [ "dev" ];
  targetPkgs =
    pkgs: with pkgs; [
      glibc.dev
      linuxHeaders
      gcc.cc
      pkg-config
      gperf
      python3
      cups
      glib
      gtk3
      google-cloud-sdk
      zlib
      expat
      nss
      nspr
      krb5
      xorg.libX11
      xorg.xorgproto
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXtst
      mesa
      dri-pkgconfig-stub
      libgbm
      libva
      libdrm
      alsa-lib
      libxkbcommon
      pango
      dbus
      at-spi2-atk
      xorg.libxcb
      cairo
      systemd
      xorg.xdpyinfo
      pipewire.dev
      libffi
      wayland.dev
      pciutils
      libGL.dev
      xorg.xinput
      xorg.libXrender
      xorg.libXi
      pulseaudio.dev
      curl.dev
      libuuid
      fontconfig.dev
      vulkan-headers
      harfbuzz.dev
      gdk-pixbuf.dev
      xorg.libxshmfence
    ];
  profile = ''
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig"
    export GN_DEFINES="use_system_libffi=true rtc_use_pipewire=true"
  '';
}
