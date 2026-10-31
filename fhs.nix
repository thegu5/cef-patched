let
  pkgs = import <nixpkgs> { };
in
pkgs.buildFHSEnv {
  name = "chromium-env";

  extraOutputsToInstall = [ "dev" ];
  targetPkgs =
    pkgs: with pkgs; [
      glibc
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
      libX11
      xorgproto
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libXtst
      libxshmfence
      mesa
      dri-pkgconfig-stub
      libgbm
      libva
      libdrm
      libglvnd
      vulkan-loader
      alsa-lib
      libxkbcommon
      pango
      dbus
      at-spi2-atk
      libxcb
      cairo
      systemd
      xdpyinfo
      pipewire
      libffi
      wayland
      pciutils
      libGL
      xinput
      libXrender
      libXi
      pulseaudio
      curl
      libuuid
      fontconfig
      vulkan-headers
      harfbuzz
      gdk-pixbuf
    ];
  profile = ''
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig"
    export GN_DEFINES="is_official_build=true symbol_level=1 treat_warnings_as_errors=false use_system_libffi=true rtc_use_pipewire=true"
  '';
}