#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 🤖 Autonomous Phone Agent (Pure Bash - v2)
# Screenshot → Qwen-VL Vision → Actions → Repeat
# Streams data to avoid memory issues on phone
# ============================================

MODEL="qwen3.5-plus"
MAX_STEPS=15
SCREENSHOT_PATH="/sdcard/agent_screen.png"
PAYLOAD_FILE="/sdcard/agent_payload.json"
RESPONSE_FILE="/sdcard/agent_response.json"

# Load API key
load_api_key() {
    local AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
    if [ -f "$AUTH_FILE" ]; then
        grep -o '"key"[[:space:]]*:[[:space:]]*"[^"]*"' "$AUTH_FILE" | head -1 | sed 's/.*"key"[[:space:]]*:[[:space:]]*"//;s/"$//'
    else
        echo "$DASHSCOPE_API_KEY"
    fi
}

# Execute an action on the phone
do_action() {
    local ATYPE="$1"
    case "$ATYPE" in
        tap)
            su -c "input tap $2 $3" 2>/dev/null
            echo "  👆 Tap ($2, $3)"
            ;;
        swipe)
            su -c "input swipe $2 $3 $4 $5 ${6:-300}" 2>/dev/null
            echo "  👆 Swipe ($2,$3)→($4,$5)"
            ;;
        type)
            local TEXT="$2"
            local ESCAPED=$(echo "$TEXT" | sed 's/ /%s/g')
            su -c "input text '$ESCAPED'" 2>/dev/null
            echo "  ⌨️ Type: $TEXT"
            ;;
        key)
            su -c "input keyevent $2" 2>/dev/null
            echo "  🔘 Key: $2"
            ;;
        open_app)
            su -c "monkey -p $2 -c android.intent.category.LAUNCHER 1" 2>/dev/null
            echo "  📱 Open: $2"
            sleep 2
            ;;
        scroll_down)
            su -c "input swipe 540 1600 540 600 300" 2>/dev/null
            echo "  ⬇️ Scroll down"
            ;;
        scroll_up)
            su -c "input swipe 540 600 540 1600 300" 2>/dev/null
            echo "  ⬆️ Scroll up"
            ;;
        go_home)
            su -c "input keyevent 3" 2>/dev/null
            echo "  🏠 Home"
            ;;
        go_back)
            su -c "input keyevent 4" 2>/dev/null
            echo "  ◀️ Back"
            ;;
        wait)
            echo "  ⏳ Wait ${2:-1}s"
            sleep "${2:-1}"
            ;;
        done)
            echo "  ✅ $2"
            ;;
    esac
}

# ============================================
# MAIN
# ============================================

if [ -z "$1" ]; then
    echo "🤖 Phone Agent (Bash v2 - Qwen)"
    echo "Usage: bash phone_agent.sh \"<task>\""
    echo ""
    echo "Examples:"
    echo '  bash phone_agent.sh "Open YouTube and search for lofi music"'
    echo '  bash phone_agent.sh "Send WhatsApp to Mom saying Hello"'
    exit 0
fi

TASK="$*"
API_KEY=$(load_api_key)

if [ -z "$API_KEY" ]; then
    echo "❌ No API key found!"
    exit 1
fi

echo ""
echo "🤖 PHONE AGENT v2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Task: $TASK"
echo "🧠 Model: $MODEL (Qwen-VL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HISTORY=""
URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

SYSTEM='You are an Android phone agent (1080x2240). You see a screenshot and a list of UI elements with exact coordinates. Use the UI element coordinates for precision.\n\nACTIONS (JSON only):\n{\"thought\": \"what I see and plan\", \"actions\": [{\"action\": \"tap\", \"x\": 540, \"y\": 500}]}\n\nAction types: tap(x,y), swipe(x1,y1,x2,y2), type(text), key(code: 3=HOME 4=BACK 66=ENTER), open_app(package), scroll_down, scroll_up, go_home, go_back, wait(seconds), done(message).\n\nPackages: com.whatsapp, com.google.android.youtube, com.instagram.android, com.android.chrome, com.android.settings\n\nIMPORTANT RULES:\n1. JSON only, 1-2 actions per step.\n2. PREFER using UI element coordinates over guessing.\n3. If a tap did not work, try DIFFERENT coordinates or a different approach.\n4. YouTube search icon is usually a magnifying glass at top-right around x=900-990, y=90-160.\n5. When you need to type, first make sure a text input field is focused (keyboard visible).\n6. Use open_app to launch apps, then wait 2-3s.\n7. Use done when the task is complete.'

for STEP in $(seq 1 $MAX_STEPS); do
    echo ""
    echo "── STEP $STEP/$MAX_STEPS ──"

    # 1. Screenshot
    echo "  📸 Capturing..."
    su -c "screencap -p $SCREENSHOT_PATH" 2>/dev/null
    sleep 0.5

    if [ ! -s "$SCREENSHOT_PATH" ]; then
        echo "  ❌ Screenshot failed"
        sleep 1
        continue
    fi

    # 2. Get UI elements for precise coordinates
    echo "  🔍 Reading UI..."
    su -c "uiautomator dump /sdcard/ui.xml" 2>/dev/null
    sleep 0.3
    UI_ELEMENTS=$(su -c "cat /sdcard/ui.xml" 2>/dev/null | grep -o 'text="[^"]*"[^>]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -20 | while read -r line; do
        txt=$(echo "$line" | sed -n 's/.*text="\([^"]*\)".*/\1/p')
        bnds=$(echo "$line" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')
        x1=$(echo "$bnds" | sed 's/\[//g;s/\]/ /g' | awk '{print $1}' | cut -d, -f1)
        y1=$(echo "$bnds" | sed 's/\[//g;s/\]/ /g' | awk '{print $1}' | cut -d, -f2)
        x2=$(echo "$bnds" | sed 's/\[//g;s/\]/ /g' | awk '{print $2}' | cut -d, -f1)
        y2=$(echo "$bnds" | sed 's/\[//g;s/\]/ /g' | awk '{print $2}' | cut -d, -f2)
        if [ -n "$x1" ] && [ -n "$y1" ] && [ -n "$x2" ] && [ -n "$y2" ]; then
            cx=$(( (x1 + x2) / 2 ))
            cy=$(( (y1 + y2) / 2 ))
            [ -n "$txt" ] && echo "$txt center($cx,$cy)"
        fi
    done 2>/dev/null)
    UI_COUNT=$(echo "$UI_ELEMENTS" | grep -c "center" 2>/dev/null)
    echo "  📋 $UI_COUNT elements"

    # 3. Build payload as a FILE (not in memory)
    ESCAPED_TASK=$(echo "$TASK" | sed 's/"/\\"/g')
    ESCAPED_UI=$(echo "$UI_ELEMENTS" | tr '\n' ' ' | sed 's/"/\\"/g')
    USER_MSG="TASK: ${ESCAPED_TASK}. Step ${STEP}/${MAX_STEPS}. ${HISTORY}UI Elements: ${ESCAPED_UI}. Analyze screenshot and UI elements, respond JSON only."

    rm -f "$PAYLOAD_FILE" 2>/dev/null

    # Build base64 image URL with MIME prefix
    BASE64_IMAGE=$(base64 "$SCREENSHOT_PATH" | tr -d '\n')
    IMAGE_URL="data:image/png;base64,${BASE64_IMAGE}"

    # Qwen-VL uses OpenAI-compatible format
    cat > "$PAYLOAD_FILE" << EOF
{
  "model": "${MODEL}",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "${SYSTEM}"},
        {"type": "image_url", "image_url": {"url": "${IMAGE_URL}"}},
        {"type": "text", "text": "${USER_MSG}"}
      ]
    }
  ],
  "temperature": 0.2,
  "max_tokens": 512
}
EOF

    PAYLOAD_SIZE=$(wc -c < "$PAYLOAD_FILE")
    echo "  📦 Payload: ${PAYLOAD_SIZE} bytes"

    # 3. Call Qwen-VL API
    echo "  🧠 Asking Qwen3.5-VL..."

    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
        -X POST "$URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "@${PAYLOAD_FILE}" \
        --connect-timeout 15 \
        --max-time 45 2>/dev/null)

    if [ "$HTTP_CODE" != "200" ]; then
        echo "  ❌ API error: HTTP $HTTP_CODE"
        if [ -f "$RESPONSE_FILE" ]; then
            ERROR_MSG=$(grep -oP '"message"\s*:\s*"\K[^"]*' "$RESPONSE_FILE" | head -1)
            echo "  ❌ $ERROR_MSG"
        fi
        if [ "$HTTP_CODE" = "429" ]; then
            echo "  ⏳ Rate limited, waiting 10s..."
            sleep 10
        fi
        continue
    fi

    # 4. Parse response (Qwen-VL format)
    # Response structure: {"choices":[{"message":{"content":"..."}}]}
    RESPONSE_TEXT=$(sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RESPONSE_FILE" | head -1)

    if [ -z "$RESPONSE_TEXT" ]; then
        echo "  ⚠️ Empty response, retrying..."
        cat "$RESPONSE_FILE" | head -5 >&2
        continue
    fi

    # Unescape: \" -> " and \\n -> newline
    CLEAN=$(echo "$RESPONSE_TEXT" | sed 's/\\"/"/g; s/\\n/ /g; s/\\t/ /g')

    # Extract thought
    THOUGHT=$(echo "$CLEAN" | sed -n 's/.*"thought"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -z "$THOUGHT" ] && THOUGHT="thinking..."
    echo "  💭 $THOUGHT"

    # 5. Execute actions
    ACTED=false

    # Check for done first
    if echo "$CLEAN" | grep -q '"done"'; then
        DONE_MSG=$(echo "$CLEAN" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        echo ""
        echo "  ✅ DONE: $DONE_MSG"
        break
    fi

    # Parse open_app (check first — it includes opening the app)
    APP_PKG=$(echo "$CLEAN" | sed -n 's/.*"open_app".*"package"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -n "$APP_PKG" ]; then
        do_action "open_app" "$APP_PKG"
        ACTED=true
    fi

    # Parse tap
    if echo "$CLEAN" | grep -q '"tap"'; then
        X=$(echo "$CLEAN" | sed -n 's/.*"tap".*"x"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        Y=$(echo "$CLEAN" | sed -n 's/.*"tap".*"y"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        if [ -n "$X" ] && [ -n "$Y" ]; then
            do_action "tap" "$X" "$Y"
            ACTED=true
        fi
    fi

    # Parse type
    if echo "$CLEAN" | grep -q '"type"'; then
        TYPE_TEXT=$(echo "$CLEAN" | sed -n 's/.*"type".*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if [ -n "$TYPE_TEXT" ]; then
            do_action "type" "$TYPE_TEXT"
            ACTED=true
        fi
    fi

    # Parse key
    if echo "$CLEAN" | grep -q '"key"'; then
        KEY_CODE=$(echo "$CLEAN" | sed -n 's/.*"key".*"code"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        if [ -n "$KEY_CODE" ]; then
            do_action "key" "$KEY_CODE"
            ACTED=true
        fi
    fi

    # Parse simple actions
    echo "$CLEAN" | grep -q '"scroll_down"' && do_action "scroll_down" && ACTED=true
    echo "$CLEAN" | grep -q '"scroll_up"' && do_action "scroll_up" && ACTED=true
    echo "$CLEAN" | grep -q '"go_back"' && do_action "go_back" && ACTED=true
    echo "$CLEAN" | grep -q '"go_home"' && do_action "go_home" && ACTED=true

    # Parse wait
    if echo "$CLEAN" | grep -q '"wait"'; then
        WAIT_SECS=$(echo "$CLEAN" | sed -n 's/.*"wait".*"seconds"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p')
        [ -n "$WAIT_SECS" ] && do_action "wait" "$WAIT_SECS" && ACTED=true
    fi

    # Parse swipe
    if echo "$CLEAN" | grep -q '"swipe"'; then
        SX1=$(echo "$CLEAN" | sed -n 's/.*"swipe".*"x1"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        SY1=$(echo "$CLEAN" | sed -n 's/.*"swipe".*"y1"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        SX2=$(echo "$CLEAN" | sed -n 's/.*"swipe".*"x2"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        SY2=$(echo "$CLEAN" | sed -n 's/.*"swipe".*"y2"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
        if [ -n "$SX1" ]; then
            do_action "swipe" "$SX1" "$SY1" "$SX2" "$SY2"
            ACTED=true
        fi
    fi

    if [ "$ACTED" = "false" ]; then
        echo "  ⚠️ No actions parsed from: $CLEAN"
    fi

    # Update history
    HISTORY="Previous: ${THOUGHT}. "

    # Wait for screen to update
    sleep 1
done

# Cleanup
rm -f "$PAYLOAD_FILE" "$PAYLOAD_FILE.head" "$PAYLOAD_FILE.tmp" "$RESPONSE_FILE" 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏁 Agent finished ($STEP steps)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
