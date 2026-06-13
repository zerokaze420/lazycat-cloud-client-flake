{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, zstd
, alsa-lib
, at-spi2-atk
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libGL
, libdrm
, libnotify
, libxkbcommon
, mesa
, nspr
, nss
, pango
, pipewire
, systemd
, libx11
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxcb
, libxshmfence
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lazycat-cloud-client";
  version = "2.0.11";

  src = fetchurl {
    url = "https://dl.lazycat.cloud/client/desktop/stable/lzc-client-desktop_v${finalAttrs.version}.tar.zst";
    hash = "sha256-EFnVqkKWr0L8xovoEVGFAQ/Vj2nuwpfDn9f3S3k6nBc=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    zstd
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libdrm
    libnotify
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxcb
    libxshmfence
  ];

  unpackPhase = ''
    runHook preUnpack
    zstd -cd $src | tar xf -
    runHook postUnpack
  '';

  postPatch = ''
    substituteInPlace cloud.lazycat.client.policy \
      --replace-fail "__SETCAP_SCRIPT_PATH__" "$out/lib/lzc-client-desktop/core/linux_setcap.sh"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/lzc-client-desktop
    mkdir -p $out/bin
    mkdir -p $out/share/polkit-1/actions
    mkdir -p $out/share/icons/hicolor/256x256/apps

    cp -r ./* $out/lib/lzc-client-desktop/

    cp icon.png $out/share/icons/hicolor/256x256/apps/lzc-client.png

    cp cloud.lazycat.client.policy $out/share/polkit-1/actions/

    cat > $out/lib/lzc-client-desktop/core/linux_setcap.sh << 'SETCAPEOF'
#!/bin/sh
exit 0
SETCAPEOF
    chmod +x $out/lib/lzc-client-desktop/core/linux_setcap.sh

    makeWrapper $out/lib/lzc-client-desktop/lzc-client-desktop $out/bin/lzc-client-desktop \
      --chdir "$out/lib/lzc-client-desktop" \
      --prefix PATH : ${lib.makeBinPath [ zstd ]}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "lzc-client";
      exec = "lzc-client-desktop";
      icon = "lzc-client";
      comment = "LazyCat micro-server client";
      desktopName = "懒猫微服";
      categories = [ "Network" ];
      mimeTypes = [ "x-scheme-handler/lzc" ];
      startupWMClass = "lzc-client-desktop";
      keywords = [ "lazycat" "lzc" ];
    })
  ];

  meta = with lib; {
    description = "LazyCat Cloud desktop client — a micro-server platform for personal cloud services";
    homepage = "https://lazycat.cloud";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "lzc-client-desktop";
    platforms = platforms.linux;
    badPlatforms = [ "aarch64-linux" ];
    maintainers = with maintainers; [ ];
  };
})
