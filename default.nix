{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, coreutils
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
  version = "2.0.26";

  src = fetchurl {
    url = "https://dl.lazycat.cloud/client/desktop/stable/lzc-client-desktop_v${finalAttrs.version}.tar.zst";
    hash = "sha256-ZEScHSgEcgnMiRAoawDqkoTXkY9Zti++g6dyKfHfDFw=";
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
watch_pid=""
watch_seconds=""
watch_interval="0.1"
for arg in "$@"; do
  case "$arg" in
    --quiet) quiet=1 ;;
    --watch) watch=1 ;;
    --watch-pid=*) watch_pid="''${arg#*=}" ;;
    --watch-seconds=*) watch_seconds="''${arg#*=}" ;;
    --watch-interval=*) watch_interval="''${arg#*=}" ;;
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
  runtime_lib_root="$HOME/.local/share/catlink/lib"
  stamp="$root/.nix-patched-catlink"
  target_interp="@glibc@/lib/ld-linux-x86-64.so.2"
  real="$bin.nix-real"
  marker="# lzc-patch-catlink wrapper"

  tree_state() {
    find "$root" \( -type f -perm -0100 -o -type f -name '*.so*' \) \
      ! -name '*.nix-real' ! -name '*.nix-wrapper' -print \
      | LC_ALL=C sort \
      | while IFS= read -r elf; do
          rel="''${elf#"$root"/}"
          printf '%s\t' "$rel"
          @coreutils@/bin/stat -c '%d:%i:%s:%Y:%y' "$elf" 2>/dev/null || true
        done
  }

  expected_stamp() {
    printf 'interpreter=%s\nruntime-library-root=%s\n' "$target_interp" "$runtime_lib_root"
    tree_state
  }

  sync_runtime_libs() {
    [ -d "$lib_root" ] || return 0
    @coreutils@/bin/mkdir -p "$runtime_lib_root"
    for bundled_lib in "$lib_root"/*.so*; do
      [ -f "$bundled_lib" ] || continue
      name="''${bundled_lib##*/}"
      @coreutils@/bin/ln -sfn "$bundled_lib" "$runtime_lib_root/$name"
    done
  }

  sync_runtime_libs

  is_wrapper() {
    [ -f "$1" ] || return 1
    line1=""
    line2=""
    {
      IFS= read -r line1
      IFS= read -r line2
    } < "$1" 2>/dev/null || true
    [ "$line2" = "$marker" ]
  }

  # Versions patched by the old implementation may be unusable because
  # patchelf rewrote their program headers.  Quarantine them so the CDE
  # plugin can download a clean copy on the next attach.
  if [ -f "$stamp" ] && ! is_wrapper "$bin"; then
    legacy_second_line=""
    {
      IFS= read -r legacy_first_line
      IFS= read -r legacy_second_line
    } < "$stamp" 2>/dev/null || true
    case "$legacy_second_line" in
      rpath=*|entry-rpath=*)
        stale_root="$HOME/.local/share/catlink-stale"
        stale_dir="$stale_root/$(basename "$root").$$"
        @coreutils@/bin/mkdir -p "$stale_root"
        if @coreutils@/bin/mv "$root" "$stale_dir"; then
          log "quarantined legacy-patched catlink: $root"
        fi
        return 0
        ;;
    esac
  fi

  # Migrate directories patched by the wrapper-based implementation back to
  # the original ELF before patching its interpreter in place.  Catlink uses
  # /proc/self/exe to locate catlink-core, so a loader wrapper makes that
  # lookup point at the glibc store instead of the Catlink directory.
  if is_wrapper "$bin" && [ -f "$real" ]; then
    @coreutils@/bin/mv -f "$real" "$bin"
  elif [ -f "$real" ]; then
    @coreutils@/bin/rm -f "$real"
  fi

  interp="$(@patchelf@/bin/patchelf --print-interpreter "$bin" 2>/dev/null || true)"
  [ -n "$interp" ] || return 0

  if [ "$interp" = "$target_interp" ]; then
    return 0
  fi

  # Only rewrite the interpreter on the two Catlink entrypoints.  Newer
  # Catlink bootloaders can crash when patchelf changes other ELF headers.
  if @patchelf@/bin/patchelf --set-interpreter "$target_interp" "$bin" \
    && expected_stamp > "$stamp"; then
    log "patched catlink: $bin"
  else
    log "failed to patch catlink: $bin"
    return 1
  fi
}

scan_once() {
  status=0
  for bin in "$HOME"/.local/share/catlink/*/catlink "$HOME"/.local/share/catlink/*/catlink-core; do
    [ -e "$bin" ] || continue
    patch_one "$bin" || status=1
  done
  return "$status"
}

if [ "$watch" -eq 1 ]; then
  i=0
  while :; do
    if [ -n "$watch_pid" ] && ! kill -0 "$watch_pid" 2>/dev/null; then
      exit 0
    fi
    scan_once || true
    if [ -n "$watch_seconds" ] && [ "$i" -ge "$watch_seconds" ]; then
      exit 0
    fi
    sleep "$watch_interval"
    i=$((i + 1))
  done
else
  scan_once
fi
PATCHCATLINKEOF
    substituteInPlace $out/bin/lzc-patch-catlink \
      --replace-fail "@patchelf@" "${patchelf}" \
      --replace-fail "@coreutils@" "${coreutils}" \
      --replace-fail "@glibc@" "${stdenv.cc.libc}"
    chmod +x $out/bin/lzc-patch-catlink

    makeWrapper $out/lib/lzc-client-desktop/lzc-client-desktop $out/bin/lzc-client-desktop \
      --chdir "$out/lib/lzc-client-desktop" \
      --prefix PATH : ${lib.makeBinPath [ coreutils fuse3 libnotify xdg-utils zstd ]} \
      --prefix PATH : /run/wrappers/bin \
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
      --run 'export LD_LIBRARY_PATH="$HOME/.local/share/catlink/lib:${lib.makeLibraryPath [
        stdenv.cc.libc
        zlib
        wayland
        libxcb
        libxkbcommon
        libglvnd
      ]}:''${LD_LIBRARY_PATH:-}"' \
      --run "$out/bin/lzc-patch-catlink --quiet || true" \
      --run "$out/bin/lzc-patch-catlink --quiet --watch --watch-pid=\$\$ --watch-interval=0.1 >/dev/null 2>&1 &"

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

    # Electron 43's crashpad handler links GLib directly.  autoPatchelf
    # may satisfy that NEEDED entry with the player's bundled GLib, which
    # removePlayerRpath then strips from non-player executables, leaving
    # chrome_crashpad_handler with no libglib provider and aborting the
    # app right after startup.  Point such executables at nixpkgs' GLib.
    ensureGlibRpath() {
      local glibLib="${lib.getLib glib}/lib"
      find "$out/lib/lzc-client-desktop" -type f -perm -0100 -print0 \
        | while IFS= read -r -d $'\0' elf; do
          case "$elf" in
            "$out/lib/lzc-client-desktop/player/lzc-player/"*) continue ;;
          esac

          needed="$(${patchelf}/bin/patchelf --print-needed "$elf" 2>/dev/null || true)"
          case "$needed" in
            *libglib-2.0.so.0*)
              rpath="$(${patchelf}/bin/patchelf --print-rpath "$elf" 2>/dev/null || true)"
              case ":$rpath:" in
                *":$glibLib:"*) ;;
                *)
                  if [ -n "$rpath" ]; then
                    ${patchelf}/bin/patchelf --set-rpath "$rpath:$glibLib" "$elf"
                  else
                    ${patchelf}/bin/patchelf --set-rpath "$glibLib" "$elf"
                  fi
                  ;;
              esac
              ;;
          esac
        done
    }

    updateNetDiagnosticManifest() {
      local nativeDir="$out/lib/lzc-client-desktop/plugin/net-diagnostic/native/linux-x64"
      local manifest="$nativeDir/build-info.json"
      local node="$nativeDir/lzc-net-diagnostic.node"

      if [ ! -f "$manifest" ] || [ ! -f "$node" ]; then
        return 0
      fi

      local actual recorded
      actual="$(sha256sum "$node" | cut -d ' ' -f 1)"
      recorded="$(sed -n '/"name": "lzc-net-diagnostic.node"/,/}/{s/.*"sha256": "\([^"]*\)".*/\1/p}' "$manifest" | head -n1)"

      if [ -n "$recorded" ] && [ "$actual" != "$recorded" ]; then
        sed -i "/\"name\": \"lzc-net-diagnostic.node\"/,/}/s/\"sha256\": \"$recorded\"/\"sha256\": \"$actual\"/" "$manifest"
      fi
    }

    postFixupHooks+=(removePlayerRpath)
    postFixupHooks+=(ensureGlibRpath)
    postFixupHooks+=(updateNetDiagnosticManifest)
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
