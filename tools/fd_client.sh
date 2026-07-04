#!/bin/bash
# FingerDump CLI client
# Usage: ./fd_client.sh [scan|scan-cat N|status|watch]

SOCKET="/var/run/fingerdumpd.sock"
CMD=""

case "$1" in
    scan)
        CMD="SCAN_ALL"
        ;;
    scan-cat)
        CMD="SCAN_CAT $2"
        ;;
    status)
        CMD="STATUS"
        ;;
    watch)
        echo "Tailing API call log..."
        tail -f /var/mobile/Library/FingerDump/api_calls.log 2>/dev/null || \
            echo "Log file not found. Is the tweak loaded?"
        exit 0
        ;;
    *)
        echo "FingerDump CLI"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  scan           Run a full identifier scan"
        echo "  scan-cat N     Scan a single category (0-10)"
        echo "  status         Check daemon status"
        echo "  watch          Tail API call log from tweak"
        echo ""
        echo "Categories:"
        echo "  0=Hardware  1=System  2=Network  3=Graphics"
        echo "  4=Audio     5=Sensor  6=Fonts    7=Persistence"
        echo "  8=Behavioral 9=Browser 10=Keychain"
        exit 1
        ;;
esac

if [ ! -S "$SOCKET" ]; then
    echo "Error: Daemon not running at $SOCKET"
    echo "Start it with: fingerdumpd --daemon"
    exit 1
fi

# Use bash built-in /dev/tcp or fall back to nc
if [ -x /usr/bin/nc ] || [ -x /bin/nc ]; then
    echo "$CMD" | nc -U -w 10 "$SOCKET" 2>/dev/null
elif [ -r /dev/tcp ]; then
    exec 3<>/dev/tcp/localhost"${SOCKET}" 2>/dev/null
    echo "$CMD" >&3
    cat <&3
    exec 3>&-
else
    # Use socat if available
    if [ -x /usr/bin/socat ]; then
        echo "$CMD" | socat - UNIX-CONNECT:"$SOCKET"
    else
        echo "Error: need nc, socat, or bash with /dev/tcp to connect"
        exit 1
    fi
fi

