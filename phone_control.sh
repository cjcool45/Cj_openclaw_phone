#!/data/data/com.termux/files/usr/bin/bash
CMD="$1"
shift

# Smart privilege detection: su (root) → rish (Shizuku) → direct
if su -c 'echo ok' 2>/dev/null | grep -q ok; then
  PRIV="root"
elif command -v rish &>/dev/null && rish -c 'echo ok' 2>/dev/null | grep -q ok; then
  PRIV="shizuku"
else
  PRIV="none"
fi

run_cmd() {
  case "$PRIV" in
    root)    su -c "$@" ;;
    shizuku) rish -c "$@" ;;
    none)    eval "$@" 2>/dev/null ;;
  esac
}

case "$CMD" in
  screenshot)
    FILENAME="${1:-/sdcard/screenshot_$(date +%s).png}"
    run_cmd "screencap '$FILENAME'"
    echo "📸 Screenshot saved: $FILENAME"
    ;;
  tap)
    run_cmd "input tap $1 $2"
    echo "👆 Tapped at ($1, $2)"
    ;;
  swipe)
    run_cmd "input swipe $1 $2 $3 $4 ${5:-300}"
    echo "👆 Swiped from ($1,$2) to ($3,$4)"
    ;;
  type)
    run_cmd "input text '$*'"
    echo "⌨️ Typed: $*"
    ;;
  key)
    run_cmd "input keyevent $1"
    echo "🔘 Key pressed: $1"
    ;;
  open-app)
    run_cmd "monkey -p $1 -c android.intent.category.LAUNCHER 1" 2>/dev/null
    echo "📱 Opened: $1"
    ;;
  kill-app)
    run_cmd "am force-stop $1"
    echo "❌ Killed: $1"
    ;;
  youtube-search)
    QUERY=$(echo "$*" | sed 's/ /+/g')
    run_cmd "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$QUERY' com.google.android.youtube"
    echo "🔍 YouTube search: $*"
    ;;
  open-url)
    run_cmd "am start -a android.intent.action.VIEW -d '$1'"
    echo "🌐 Opened: $1"
    ;;
  whatsapp-send)
    NUM="$1"; shift; MSG=$(echo "$*" | sed 's/ /%20/g')
    run_cmd "am start -a android.intent.action.VIEW -d 'https://wa.me/$NUM?text=$MSG'"
    echo "📱 WhatsApp to $NUM"
    ;;
  playstore-search)
    QUERY=$(echo "$*" | sed 's/ /+/g')
    run_cmd "am start -a android.intent.action.VIEW -d 'market://search?q=$QUERY'"
    echo "🔍 Play Store search: $*"
    ;;
  install-app)
    run_cmd "am start -a android.intent.action.VIEW -d 'market://details?id=$1'"
    echo "📦 Opened Play Store for: $1"
    ;;
  wifi)
    case "$1" in
      on)  run_cmd "svc wifi enable"  && echo "📶 WiFi ON" ;;
      off) run_cmd "svc wifi disable" && echo "📶 WiFi OFF" ;;
    esac
    ;;
  bluetooth)
    case "$1" in
      on)  run_cmd "svc bluetooth enable"  && echo "🔵 Bluetooth ON" ;;
      off) run_cmd "svc bluetooth disable" && echo "🔵 Bluetooth OFF" ;;
    esac
    ;;
  airplane)
    case "$1" in
      on)  run_cmd "cmd connectivity airplane-mode enable" && echo "✈️ Airplane ON" ;;开) run_cmd"cmd connectivity airplane-mode enable"&& echo"✈️ 飞机模式已开启" ;;
      off) run_cmd "cmd connectivity airplane-mode disable" && echo "✈️ Airplane OFF" ;;关) run_cmd"cmd connectivity airplane-mode disable"&& echo"✈️ 飞机模式已关闭"“✈️ 飞机模式已关闭” ;;
    esac
    ;;
  brightness)亮度)
    run_cmd "settings put system screen_brightness “settings put system screen_brightness”$1"
    echo "🔆 Brightness: $1/255"echo" 亮度：$1/255"
    ;;
  send-sms)发送短信)
    NUM="$1"; shift; MSG="$*"
    run_cmd "am start -a android.intent.action.SENDTO -d sms:$NUM --es sms_body '$MSG'"
    echo "📩 SMS to $NUM"echo" 发送短信至$NUM"echo" 短信发送至$NUM"echo" 发送短信至$NUM"
    ;;
  call)呼叫)
    run_cmd "am start -a android.intent.action.CALL -d tel:$1"
    echo "📞 Calling: $1"echo" 正在呼叫：$1"echo" 正在呼叫：$1"echo" 正在呼叫：$1"echo" 正在呼叫：$1"echo" 正在呼叫：$1"echo" 正在呼叫：$1"
    ;;
  battery)电池)
    run_cmd "dumpsys battery" | grep "level"
    ;;
  home)首页)
    run_cmd "input keyevent 3"run_cmd"输入按键事件3"
    echo "🏠 Home"echo" 首页"
    ;;
  back)返回)
    run_cmd "input keyevent 4"run_cmd"输入按键事件4"
    echo "◀️ Back"echo"◀️ 返回"
    ;;
  *)
    echo "Usage: bash phone_control.sh [command] [args]"echo"用法：bash phone_control.sh [命令] [参数]"
    echo "Commands: screenshot, tap, swipe, type, key, open-app, kill-app,"echo"命令：screenshot, tap, swipe, type, key, open-app, kill-app,"
    echo "  youtube-search, open-url, whatsapp-send, playstore-search,"
    echo "  wifi, bluetooth, airplane, brightness, battery, call, send-sms"
    ;;
esac
