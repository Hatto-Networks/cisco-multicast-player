#!/bin/bash

# hatto networks 2026

# Defaults
SRC_DIR="./audio"
TEMP_FILE_DIR="./.broadcasttemp"
TEMP_FILE_BACKUP_DIR="./.broadcasttempbackup"
PHONE_CONF="./phones.conf"
AUTHORIZATION_CONF="./.broadcastauthorization"
MCAST_IP="239.255.255.250"
PORT="20480"
AUTH_HEADER="Authorization: Basic YWRtaW46Q2lzY28=" # admin:Cisco (default 7925 creds)
OVERRIDE_AUTH_HEADER=false
MISC_FFMPEG_SWITCHES=(-loglevel error)
MISC_VLC_SWITCHES="--quiet"

# Welcome msg
echo -e "cisco-multicast-player by hatto networks. Press ^C at any time to quit."

# Handle CTRL+C
cleanup() {
    echo -e "\n[!] Quitting..."
    if [ ! "$NOCLEANUP" = true ] ; then
        echo -e " → Removing temp directories..."
        rm -rf "$TEMP_FILE_DIR"
        rm -rf "$TEMP_FILE_BACKUP_DIR"
    fi
    for ip in "${PHONE_IPS[@]}"; do
        echo -n " → Sending stop multicast request to $ip..."
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$ip/CGI/Execute" \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode 'XML=<CiscoIPPhoneExecute><ExecuteItem URL="RTPMRx:Stop" /></CiscoIPPhoneExecute>')
        if [ "$http_code" = "200" ]; then
            echo "OK"
        else
            echo "Failed (HTTP $http_code)"
        fi
    done
    echo "[✓] Exited."
    exit 0
}
trap cleanup SIGINT

# Get switch options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--device-ip)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            DEVICE_IPS=$(echo "$2" | tr ',' '\n')
            shift 2
            ;;
        -f|--file)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            ONEFILE="$2"
            shift 2
            ;;
        -d|--directory)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            SRC_DIR="$2"
            shift 2
            ;;
        -c|--credentials)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            OVERRIDE_AUTH_HEADER=true
            AUTH_HEADER="Authorization: Basic $(printf '%s' "$2" | base64 -w0)"
            shift 2
            ;;
        -m|--multicast-ip)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            MCAST_IP="$2"
            shift 2
            ;;
        -p|--multicast-port)
            [[ -z "$2" ]] && { echo "Nothing specified for $1!"; exit 1; }
            PORT="$2"
            shift 2
            ;;
        -s|--shuffle)
            SHUFFLE=true
            shift
            ;;
        -r|--repeat)
            REPEAT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--nocleanup)
            NOCLEANUP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Read phone ips
if [[ -v DEVICE_IPS ]]; then
    mapfile -t PHONE_IPS <<< "$DEVICE_IPS" # overrides IPs in the .conf if the switch is specified
else
    if [ -f "$PHONE_CONF" ]; then
        mapfile -t PHONE_IPS < "$PHONE_CONF"
    else
        echo "[!] Config file not found. Either specify device IP(s) manually with -i (seperated by comma if multiple) or put device IP(s) in $PHONE_CONF (seperated by newline if multiple); exiting."
        exit 1
    fi
fi

# Set credentials if variable not set
if [ "$OVERRIDE_AUTH_HEADER" = false ] ; then
    if [ -f "$AUTHORIZATION_CONF" ]; then
        OVERRIDE_AUTH_HEADER=true
        AUTH_HEADER="Authorization: Basic $(cat "$AUTHORIZATION_CONF" | tr -d '\n')"
    else
        echo "[*] Credentials file not found. Using default."
    fi
fi

# Verbose output
if [ "$VERBOSE" = true ] ; then
    MISC_FFMPEG_SWITCHES=(-loglevel verbose)
    MISC_VLC_SWITCHES="-vv"

    BOLD="\033[1m"; CYAN="\033[36m"; RESET="\033[0m"
    echo -e "  ${CYAN}SRC_DIR${RESET}       : $SRC_DIR"
    echo -e "  ${CYAN}TEMP_FILE_DIR${RESET} : $TEMP_FILE_DIR"
    echo -e "  ${CYAN}TEMP_FILE_BACKUP_DIR${RESET} : $TEMP_FILE_BACKUP_DIR"
    echo -e "  ${CYAN}PHONE_CONF${RESET}    : $PHONE_CONF"
    echo -e "  ${CYAN}MCAST_IP${RESET}      : $MCAST_IP"
    echo -e "  ${CYAN}PORT${RESET}          : $PORT"
    echo -e "  ${CYAN}AUTH_HEADER${RESET}   : $(echo "$AUTH_HEADER" | awk 'match($0,/^(Authorization: Basic )([A-Za-z0-9+\/=]+)/,m){print m[1] substr(m[2],1,int(length(m[2])/4)) "...";next}1')" # censor the first few chars of auth header
fi

# Check if audio directory exists and has audio files in it
if [[ -d "$SRC_DIR" && -n "$(ls -A "$SRC_DIR")" ]]; then
    selected=$(find "$SRC_DIR" -maxdepth 1 -type f -print0 | xargs -0 file --mime-type | awk -F: '$2 ~ /audio\// {print $1}' | shuf -n 1)
    if [[ -z "$selected" ]]; then
        echo "[!] No audio files found. Either specify a different directory with -d or put audio files in $SRC_DIR; exiting."
        exit 1
    fi
else
    echo "[!] Audio directory not found/empty. Either specify a valid non-empty directory with -d or create $SRC_DIR; exiting."
    exit 1
fi

# Ensure temp directories exists
mkdir -p "$TEMP_FILE_DIR"
mkdir -p "$TEMP_FILE_BACKUP_DIR"

# Convert all audio files to ulaw for the phonez
echo "[*] Converting audio files..."
if [[ -v ONEFILE ]]; then
    mime=$(file -bi "$ONEFILE")
    if [[ "$mime" == audio/* ]]; then
        base=$(basename "$ONEFILE")
        outname="${base%.*}.wav"
        out="$TEMP_FILE_DIR/$outname"
        if [ ! -f "$out" ]; then
            echo " → Converting: $(basename "$ONEFILE") → $(basename "$out")"
            ffmpeg "${MISC_FFMPEG_SWITCHES[@]}" -i "$ONEFILE" -ar 8000 -ac 1 -c:a pcm_mulaw "$out"
        fi
    fi
else
    for file in "$SRC_DIR"/*; do
        [ -f "$file" ] || continue
        mime=$(file -bi "$file")
        [[ "$mime" == audio/* ]] || continue
        base=$(basename "$file")
        outname="${base%.*}.wav"
        out="$TEMP_FILE_DIR/$outname"
        if [ ! -f "$out" ]; then
            echo " → Converting: $(basename "$file") → $(basename "$out")"
            ffmpeg "${MISC_FFMPEG_SWITCHES[@]}" -i "$file" -ar 8000 -ac 1 -c:a pcm_mulaw "$out"
        fi
    done
fi

# Backup converted files if repeat
if [ "$REPEAT" = true ]; then
    cp -r "$TEMP_FILE_DIR"/* "$TEMP_FILE_BACKUP_DIR"
fi

# Send join request to phones to multicast
echo "[*] Sending join requests to phone(s)..."
    for ip in "${PHONE_IPS[@]}"; do
        echo -n " → Sending to $ip..."
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$ip/CGI/Execute" \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode "XML=<CiscoIPPhoneExecute><ExecuteItem URL=\"RTPMRx:$MCAST_IP:$PORT\" /></CiscoIPPhoneExecute>")
        if [ "$http_code" = "200" ]; then
            echo "OK"
        else
            echo "Failed (HTTP error $http_code)"
        fi
    done

# Play stuff!
while true; do
    if [ "$SHUFFLE" = true ]; then
        selected=$(find "$TEMP_FILE_DIR" -type f -iname "*.wav" | shuf -n 1)
    else
        selected=$(find "$TEMP_FILE_DIR" -type f -iname "*.wav" | sort | head -n 1)
    fi

    if [ -z "$selected" ]; then
        if [ "$REPEAT" = true ]; then
            echo "[✓] End of playlist. Repeating."
            rm -rf "${TEMP_FILE_DIR:?}"/*
            cp -r "$TEMP_FILE_BACKUP_DIR"/* "$TEMP_FILE_DIR/"
            continue
        else
            echo "[✓] End of playlist."
            cleanup
        fi
    fi

    echo "[▶] Now playing $(basename "$selected")."
    cvlc --no-audio "${MISC_VLC_SWITCHES[@]}" "$selected" --sout="#transcode{acodec=ulaw,channels=1,samplerate=8000}:rtp{dst=$MCAST_IP,port=$PORT}" \
    vlc://quit

    sleep 1
    rm -f "$selected"
done