#!/bin/bash
# Iru library script, Sable Trial only, pushed by Onboarding.
# GitHub classic token with only the read:packages scope. On the Onboarding box the secret
# is named github-trial-packages-token. Paste it into token= in the Iru item. The Mac never
# reads the box, and this file in git stays empty. Never commit the token.
# Writes ~/.bunfig.toml and ~/.config/.bunfig.toml for the sable user (mode 600) only when TRIAL_TYPE=ds.
# Engineering and every other trial type get no token. bun prefers bunfig over ~/.npmrc.
# Writes the token only into those two bunfig files, and does not touch credentials.json.
# Never copy ~/.config/sable/credentials.json from another machine.
set -euo pipefail
token=""

die() { echo "FAIL: $*"; exit 1; }

[ -n "$token" ] || die "token is empty: paste github-trial-packages-token into this Iru item (read:packages only)"

home=$(dscl . -read /Users/sable NFSHomeDirectory | awk '{print $2}')
[ -n "$home" ] || die "no home directory for user sable"
inputs="$home/trial-inputs.env"
if [ ! -s "$inputs" ]; then
  die "no $inputs yet. sable-setup fetches the list first; this script writes the token on a later check-in, then run sable-setup again"
fi
trial_type=$(sed -n 's/^TRIAL_TYPE="\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' "$inputs" | head -1)
if [ "$trial_type" != ds ]; then
  echo "TRIAL_TYPE=${trial_type:-empty} is not ds; not writing ~/.bunfig.toml"
  unset token
  exit 0
fi
# Bun reads $XDG_CONFIG_HOME/.bunfig.toml instead of ~/.bunfig.toml when XDG_CONFIG_HOME is set, so write both
# (trial1 Nov 23 2026: a terminal with XDG_CONFIG_HOME missed ~/.bunfig.toml and got 403). sable-setup copies the
# scope to any other path bun may read. Written AS sable (never a root redirect into a path sable controls): the
# token goes in on stdin, opens are O_NOFOLLOW relative to a no-follow directory fd (a symlinked ~/.config or target
# fails), only the "@sable-inc" scope line is replaced (other Bun settings stay), via a temp file and an atomic rename.
merge_py='import os,re,sys
home,rel=sys.argv[1],sys.argv[2]
tok=sys.stdin.read().strip()
if not tok or chr(34) in tok or chr(10) in tok: sys.exit(3)
parts=rel.split("/")
fd=os.open(home,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
for d in parts[:-1]:
    try: os.mkdir(d,0o700,dir_fd=fd)
    except FileExistsError: pass
    n=os.open(d,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd); os.close(fd); fd=n
name=parts[-1]
try:
    rf=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd)
    with os.fdopen(rf) as fh: lines=fh.read().splitlines()
except FileNotFoundError: lines=[]
scope=re.compile(r"^\s*\W?@sable-inc\W?\s*=")
kept=[l for l in lines if not scope.match(l)]
line="\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"%s\" }" % tok
st=[k.strip() for k in kept]
if "[install.scopes]" in st: kept.insert(st.index("[install.scopes]")+1,line)
else: kept+=([""] if kept else [])+["[install.scopes]",line]
tmp=name+".sable-tmp"
try: os.unlink(tmp,dir_fd=fd)
except FileNotFoundError: pass
w=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=fd)
os.write(w,("\n".join(kept)+"\n").encode()); os.fchmod(w,0o600); os.close(w)
os.replace(tmp,name,src_dir_fd=fd,dst_dir_fd=fd); os.close(fd)'
for rel in .bunfig.toml .config/.bunfig.toml; do
  if printf '%s' "$token" | sudo -u sable -H /usr/bin/python3 -I -c "$merge_py" "$home" "$rel" >/dev/null 2>&1; then
    echo "wrote $home/$rel (mode 600, other Bun settings kept). The token was not printed."
  else die "$home/$rel not written (a symlinked ~/.config or target is refused, not followed)"; fi
done
unset token
