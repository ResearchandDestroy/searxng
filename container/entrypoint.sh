#!/bin/sh
# shellcheck shell=dash
set -u

# Check if it's a valid file
check_file() {
    local target="$1"

    if [ ! -f "$target" ]; then
        cat <<EOF
!!!
!!! ERROR
!!! "$target" is not a valid file, exiting...
!!!
EOF
        exit 1
    fi
}

# Check if it's a valid directory
check_directory() {
    local target="$1"

    if [ ! -d "$target" ]; then
        cat <<EOF
!!!
!!! ERROR
!!! "$target" is not a valid directory, exiting...
!!!
EOF
        exit 1
    fi
}

setup_ownership() {
    local target="$1"
    local type="$2"

    case "$type" in
        file | directory) ;;
        *)
            cat <<EOF
!!!
!!! ERROR
!!! "$type" is not a valid type, exiting...
!!!
EOF
            exit 1
            ;;
    esac

    target_ownership=$(stat -c %U:%G "$target")

    if [ "$target_ownership" != "searxng:searxng" ]; then
        if [ "${FORCE_OWNERSHIP:-true}" = true ] && [ "$(id -u)" -eq 0 ]; then
            chown -R searxng:searxng "$target"
        else
            cat <<EOF
!!!
!!! WARNING
!!! "$target" $type is not owned by "searxng:searxng"
!!! This may cause issues when running SearXNG
!!!
!!! Expected "searxng:searxng"
!!! Got "$target_ownership"
!!!
EOF
        fi
    fi
}

# Handle volume mounts
volume_handler() {
    local target="$1"

    check_directory "$target"
    setup_ownership "$target" "directory"
}

setup() {
    local template_settings="/usr/local/searxng/settings.template.yml"
    local target_settings="$__SEARXNG_CONFIG_PATH/settings.yml"

    if [ ! -f "$target_settings" ]; then
        cp -pfT "$template_settings" "$target_settings"

        sed -i "s/ultrasecretkey/$(head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')/g" "$target_settings"
    fi

    check_file "$target_settings"
}

echo "DorXNG Server Codename: dorx-cannon v2"

# Check for volume mounts
volume_handler "$__SEARXNG_CONFIG_PATH"
volume_handler "$__SEARXNG_DATA_PATH"

setup

# root only features
if [ "$(id -u)" -eq 0 ]; then
    update-ca-certificates
fi

# ENVs aliases
# https://github.com/searxng/searxng/issues/5934
case "${SEARXNG_PORT:-}" in
    '') ;;
    *[!0-9]*)
        unset SEARXNG_PORT
        ;;
    *)
        export GRANIAN_PORT="$SEARXNG_PORT"
        ;;
esac

# Start Tor
printf '\nStarting Tor... Please Wait...\n'
tor >/dev/null 2>&1

# Check Tor
printf '\nChecking Tor Connectivity...\n'
tor_check=""
for _ in $(seq 1 12); do
    sleep 5
    tor_check=$(curl -x socks5h://127.0.0.1:9050 -s -m 10 https://check.torproject.org/api/ip) && break
done
printf '%s\n\n' "${tor_check:-Tor connectivity check failed}"

# Display IP Configuration
printf 'IP Configuration:\n'
ip a s eth0 | grep inet | awk '{print $2}'
printf '\n'

# Generate Self-Signed Certificate
printf 'Generating Self-Signed Certificate...\n\n'
/usr/local/searxng/generate_self-signed_cert.sh

# Start nginx
printf 'Starting Nginx:\n'
nginx >/dev/null 2>&1
netstat -tnl | grep -E ':(80|443) ' | awk '{print $4}'

# Print Server Target
printf "\nSend Search Queries to:\nhttps://%s/search\n" "$(ip a s eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"

# SearXNG Monitor
printf '\nStarting SearXNG Monitor...\n'
/usr/local/searxng/searxng-monitor.sh &

# Start SearXNG
printf '\nStarting SearXNG...\n'
printf 'Listening on %s:%s\n' "$GRANIAN_HOST" "$GRANIAN_PORT"
exec /usr/local/searxng/.venv/bin/granian searx.webapp:app 2>/dev/null
