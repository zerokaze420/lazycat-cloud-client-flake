{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, patchelf
, fuse3
, zstd
, zlib
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
, libglvnd
, libnotify
, libsecret
, libva
, libvdpau
, libxkbcommon
, libjack2
, mesa
, nspr
, nss
, pango
, pipewire
, systemd
, e2fsprogs
, wayland
, vulkan-loader
, xdg-utils
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
  version = "2.0.22";

  src = fetchurl {
    url = "https://dl.lazycat.cloud/client/desktop/stable/lzc-client-desktop_v${finalAttrs.version}.tar.zst";
    hash = "sha256-nVAHYYrGIc04s+MGSip+GEeb4Amy2u8Nz67JE0TBXr4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    zstd
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    # Optional legacy Wayland shell plugin; upstream does not ship the
    # matching Qt 6.8 private integration library.
    "libQt6WlShellIntegration.so.6"
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
    libsecret
    libva
    libvdpau
    libxkbcommon
    libjack2
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    e2fsprogs
    vulkan-loader
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
    substituteInPlace cloud.lazycat.client.policy \
      --replace-fail "auth_admin" "yes"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/lzc-client-desktop
    mkdir -p $out/bin
    mkdir -p $out/share/polkit-1/actions
    mkdir -p $out/share/icons/hicolor/256x256/apps

    cp -r ./* $out/lib/lzc-client-desktop/

    mv $out/lib/lzc-client-desktop/core/lzc-core $out/lib/lzc-client-desktop/core/.lzc-core-wrapped

    cat > $out/lib/lzc-client-desktop/core/lzc-core << 'WRAPPEREOF'
#!/bin/sh
if [ -x /run/wrappers/bin/lzc-core ]; then
  exec /run/wrappers/bin/lzc-core "$@"
fi
exec "$(dirname "$0")/.lzc-core-wrapped" "$@"
WRAPPEREOF
    chmod +x $out/lib/lzc-client-desktop/core/lzc-core

    cp icon.png $out/share/icons/hicolor/256x256/apps/lzc-client.png

    cp cloud.lazycat.client.policy $out/share/polkit-1/actions/

    cat > $out/lib/lzc-client-desktop/core/linux_setcap.sh << 'SETCAPEOF'
#!/bin/sh
exit 0
SETCAPEOF
    chmod +x $out/lib/lzc-client-desktop/core/linux_setcap.sh

    mkdir -p $out/lib/lzc-client-desktop/fake/bin
    cat > $out/lib/lzc-client-desktop/fake/bin/getcap << 'GETCAPEOF'
#!/bin/sh
for p in "$@"; do
  case "$p" in
    *lzc-core*)
      printf '%s cap_net_admin=ep\n' "$p"
      ;;
  esac
done
GETCAPEOF
    chmod +x $out/lib/lzc-client-desktop/fake/bin/getcap

    cat > $out/bin/lzc-patch-catlink << 'PATCHCATLINKEOF'
#!/bin/sh
set -u

quiet=0
watch=0
for arg in "$@"; do
  case "$arg" in
    --quiet) quiet=1 ;;
    --watch) watch=1 ;;
  esac
done

log() {
  if [ "$quiet" -eq 0 ]; then
    printf '%s\n' "$*" >&2
  fi
}

patch_one() {
  bin="$1"
  [ -f "$bin" ] || return 0
  [ -w "$bin" ] || return 0

  root="$(dirname "$bin")"
  lib_root="$root/lib"
  stamp="$root/.nix-patched-catlink"
  target_interp="@glibc@/lib/ld-linux-x86-64.so.2"
  target_rpath="$lib_root:$lib_root/lib:@glibc@/lib:@zlib@/lib:@wayland@/lib:@libxcb@/lib:@libxkbcommon@/lib:@libglvnd@/lib"

  interp="$(@patchelf@/bin/patchelf --print-interpreter "$bin" 2>/dev/null || true)"

  if [ "$interp" = "$target_interp" ] \
    && [ -f "$stamp" ] \
    && [ "$(cat "$stamp" 2>/dev/null || true)" = "$target_rpath" ]; then
    return 0
  fi

  if @patchelf@/bin/patchelf --set-interpreter "$target_interp" "$bin" \
    && find "$root" \( -type f -perm -0100 -o -type f -name '*.so*' \) -print \
      | while IFS= read -r elf; do
          @patchelf@/bin/patchelf --set-rpath "$target_rpath" "$elf" 2>/dev/null || true
        done \
    && printf '%s' "$target_rpath" > "$stamp"; then
    log "patched catlink: $bin"
  else
    log "failed to patch catlink: $bin"
    return 1
  fi
}

scan_once() {
  status=0
  for bin in "$HOME"/.local/share/catlink/*/catlink; do
    [ -e "$bin" ] || continue
    patch_one "$bin" || status=1
  done
  return "$status"
}

if [ "$watch" -eq 1 ]; then
  i=0
  while [ "$i" -lt 600 ]; do
    scan_once || true
    sleep 0.5
    i=$((i + 1))
  done
else
  scan_once
fi
PATCHCATLINKEOF
    substituteInPlace $out/bin/lzc-patch-catlink \
      --replace-fail "@patchelf@" "${patchelf}" \
      --replace-fail "@glibc@" "${stdenv.cc.libc}" \
      --replace-fail "@zlib@" "${zlib}" \
      --replace-fail "@wayland@" "${wayland}" \
      --replace-fail "@libxcb@" "${libxcb}" \
      --replace-fail "@libxkbcommon@" "${libxkbcommon}" \
      --replace-fail "@libglvnd@" "${libglvnd}"
    chmod +x $out/bin/lzc-patch-catlink

    makeWrapper $out/lib/lzc-client-desktop/lzc-client-desktop $out/bin/lzc-client-desktop \
      --chdir "$out/lib/lzc-client-desktop" \
      --prefix PATH : /run/wrappers/bin \
      --prefix PATH : ${lib.makeBinPath [ fuse3 libnotify xdg-utils zstd ]} \
      --prefix PATH : $out/lib/lzc-client-desktop/fake/bin \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
        dbus
        libGL
        libdrm
        libglvnd
        libnotify
        libva
        libxext
        libxfixes
        libxkbcommon
        libxrandr
        mesa
        vulkan-loader
      ]} \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib \
      --set-default LIBVA_DRIVERS_PATH /run/opengl-driver/lib/dri:${mesa}/lib/dri \
      --set-default __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d:${libglvnd}/share/glvnd/egl_vendor.d \
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
      --run "$out/bin/lzc-patch-catlink --quiet || true" \
      --run "$out/bin/lzc-patch-catlink --quiet --watch >/dev/null 2>&1 &"

    runHook postInstall
  '';

  preFixup = ''
    # autoPatchelf sees the player's bundled libraries and may add that
    # directory to unrelated executables.  In particular, its older GLib
    # must not be mixed with nixpkgs' GObject/GIO used by Electron.
    removePlayerRpath() {
      local playerLib="$out/lib/lzc-client-desktop/player/lzc-player/usr/lib"
      find "$out/lib/lzc-client-desktop" -type f -perm -0100 -print0 \
        | while IFS= read -r -d $'\0' elf; do
          case "$elf" in
            "$out/lib/lzc-client-desktop/player/lzc-player/"*) continue ;;
          esac

          rpath="$(${patchelf}/bin/patchelf --print-rpath "$elf" 2>/dev/null || true)"
          case ":$rpath:" in
            *":$playerLib:"*)
              cleanRpath=""
              oldIFS="$IFS"
              IFS=:
              for path in $rpath; do
                [ "$path" = "$playerLib" ] && continue
                if [ -n "$cleanRpath" ]; then
                  cleanRpath="$cleanRpath:$path"
                else
                  cleanRpath="$path"
                fi
              done
              IFS="$oldIFS"
              ${patchelf}/bin/patchelf --set-rpath "$cleanRpath" "$elf"
              ;;
          esac
        done
    }

    postFixupHooks+=(removePlayerRpath)
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
