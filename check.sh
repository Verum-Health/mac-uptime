#!/usr/bin/env bash
# Outside alarm: the office Mac sets the HEARTBEAT_AT repo variable every 5 min.
# If it stops for 15+ min, alert once, then hourly while it stays down.
set -euo pipefail
now=$(date +%s)
hb=${HB:-0}
[[ "$hb" =~ ^[0-9]+$ ]] || hb=0
stale=$(( (now - hb) / 60 ))
last=$(cat state/last_alert 2>/dev/null || echo 0)
hbtxt=$(TZ=America/Chicago date -d "@$hb" '+%a %-I:%M %p CT' 2>/dev/null || TZ=America/Chicago date -r "$hb" '+%a %-I:%M %p CT')
send() {
  curl -s -m 15 -o /dev/null -w 'telegram http %{http_code}\n' -X POST \
    "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" --data-urlencode "text=$1"
}
echo "stale=${stale}min"
if [ "${TEST:-false}" = "true" ]; then
  send "TEST from the outside alarm (GitHub). The office Mac last checked in ${stale} min ago (${hbtxt}). No action needed."
  exit 0
fi
commit=0
if [ "$stale" -ge 15 ] && { [ "$last" -le "$hb" ] || [ $(( now - last )) -ge 3600 ]; }; then
  send "⚠️ The office Mac Studio has been silent for ${stale} min (last check-in ${hbtxt}). Power, internet or the gateway is down, and the Mac can't alert you itself. Check it, or connect over Tailscale and run: kelly-recover"
  echo "$now" > state/last_alert
  commit=1
fi
if [ "${SCHED:-}" = "17 9 * * 1" ]; then date -u +%FT%TZ > state/keepalive; commit=1; fi
if [ "$commit" = 1 ]; then
  git config user.name uptime-bot
  git config user.email uptime-bot@users.noreply.github.com
  git add state
  git commit -qm "state" && git push -q
fi
