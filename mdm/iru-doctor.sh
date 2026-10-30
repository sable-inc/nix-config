#!/bin/bash
# Iru custom script, run daily. Shows sable-doctor's report on the device page in Iru;
# the item fails when any check fails, including before the bootstrap has finished.
doctor=/run/current-system/sw/bin/sable-doctor
[ -x "$doctor" ] || { echo "sable-doctor not installed yet; the bootstrap has not finished"; exit 1; }
# An interactive zsh, so PATH and NPM_TOKEN match what the trialer's terminal sees.
exec sudo -H -u sable /bin/zsh -ic "$doctor" 2>&1
