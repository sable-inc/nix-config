# Per-slot API keys written by trial-tools slot-creds. Loaded only if the file is ours and nobody else can
# write it (a group/other-writable file here would run as the user at every shell start).
_sable_env="$HOME/.config/sable/env"
if [ -r "$_sable_env" ]; then
  # GNU stat first: on Linux `stat -f` means filesystem status and succeeds with the wrong output.
  _o=$(stat -c %u "$_sable_env" 2>/dev/null || stat -f %u "$_sable_env" 2>/dev/null)
  _m=$(stat -c %a "$_sable_env" 2>/dev/null || stat -f %Lp "$_sable_env" 2>/dev/null)
  if [ "$_o" = "$(id -u)" ] && [ $(( 8#$_m & 18 )) -eq 0 ]; then
    # shellcheck disable=SC1090
    . "$_sable_env"
  else
    echo "sable: not loading $_sable_env (must be owned by you and not group/other writable)" >&2
  fi
fi
unset _sable_env _o _m
