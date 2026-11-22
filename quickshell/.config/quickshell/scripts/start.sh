#!/usr/bin/env bash
# Starts Quickshell; the autostart (hypr/conf/autostart.lua) and `lyne reload`
# both run this, so the shell always starts the same way.
#
# * 2 jemalloc arenas: by default every new worker thread gets an arena that
#   keeps its memory after the thread ends (~70 MB more RSS, same CPU).
# * Howdy: its PAM module passes openlog() a pointer into itself and is
#   unloaded after pam_end, so the next PAM log in the same process can crash
#   it, which would leave a locked session stuck. When the lock's PAM service
#   (lock.pamService in state.json, default "login") uses pam_howdy.so, the
#   module is preloaded so it is never unloaded. Only for this process.

STATE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state.json"

service=""
if [[ -r "$STATE" ]] && command -v jq >/dev/null; then
    service="$(jq -r '.lock.pamService // empty | strings' "$STATE" 2>/dev/null)"
fi
[[ -n "$service" && "$service" != */* && -f "/etc/pam.d/$service" ]] || service="login"

howdy=""
for so in /usr/lib64/security/pam_howdy.so /usr/lib/security/pam_howdy.so; do
    [[ -r "$so" ]] && { howdy="$so"; break; }
done

if [[ -n "$howdy" ]] && grep -Eq '^[[:space:]]*auth[[:space:]].*pam_howdy\.so' "/etc/pam.d/$service" 2>/dev/null; then
    export LD_PRELOAD="$howdy${LD_PRELOAD:+:$LD_PRELOAD}"
fi

export MALLOC_CONF=narenas:2
exec quickshell "$@"
