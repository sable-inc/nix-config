# Orca (orca.dev) has no Homebrew cask, so activation installs it from its GitHub release
# when it is missing. Orca updates itself after that, so the app is owned by the user.
# Trial laptops skip it.
{
  config,
  lib,
  user,
  ...
}:
lib.mkIf (config.sable.profile != "trial") {
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [ ! -d /Applications/Orca.app ]; then
      echo "installing Orca..." >&2
      orca_tmp="$(mktemp -d)"
      if /usr/bin/curl --proto '=https' --tlsv1.2 -fsSL -o "$orca_tmp/orca.dmg" \
          https://github.com/stablyai/orca/releases/latest/download/orca-macos-arm64.dmg \
        && /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$orca_tmp/mnt" "$orca_tmp/orca.dmg" >/dev/null; then
        # Only install the app if Orca's developer (Lovecast LLC) signed it.
        if /usr/bin/codesign --verify --deep --strict "$orca_tmp/mnt/Orca.app" \
          && /usr/bin/codesign -dv "$orca_tmp/mnt/Orca.app" 2>&1 | grep -q '^TeamIdentifier=6CX3WHS9HZ$'; then
          /usr/bin/ditto "$orca_tmp/mnt/Orca.app" /Applications/Orca.app
          /usr/sbin/chown -R ${user}:staff /Applications/Orca.app
        else
          echo "warning: Orca's signature didn't check out, not installing it" >&2
        fi
        /usr/bin/hdiutil detach -quiet "$orca_tmp/mnt" || true
      else
        echo "warning: couldn't download Orca, the next build-switch will try again" >&2
      fi
      rm -rf "$orca_tmp"
    fi
  '';
}
