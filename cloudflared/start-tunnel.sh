#!/usr/bin/env bash
set -uo pipefail

CONTAINER_NAME="nextcloud"
TRUSTED_DOMAIN_INDEX="1"
STATE_FILE="/state/discord_message_id"
DELETE_PREVIOUS_MESSAGE="${DELETE_PREVIOUS_MESSAGE:-true}"

WEBHOOK="${DISCORD_WEBHOOK_URL%/}"

if [[ -z "$WEBHOOK" ]]; then
    echo "ERROR: DISCORD_WEBHOOK_URL is missing"
    exit 1
fi

while true; do
    echo "Starting Cloudflare Quick Tunnel..."
    notification_sent=0

    while IFS= read -r line; do
        echo "$line"

        if [[ "$notification_sent" -eq 0 &&
              "$line" =~ (https://[a-zA-Z0-9.-]+\.trycloudflare\.com) ]]; then

            url="${BASH_REMATCH[1]}"
            host="${url#https://}"
            host="${host%/}"

            # Avoid processing the same announcement twice in this tunnel.
            notification_sent=1

            echo "URL detected: $url"
            echo "Updating trusted_domains..."

            if ! docker exec -u www-data "$CONTAINER_NAME" \
                php occ config:system:set trusted_domains \
                "$TRUSTED_DOMAIN_INDEX" --value="$host"; then
                echo "ERROR: the domain could not be added."
                continue
            fi

            echo "Domain added successfully."

            # Delete the previous card, if there is one.
            if [[ "$DELETE_PREVIOUS_MESSAGE" == "true" &&
                  -s "$STATE_FILE" ]]; then

                old_id="$(cat "$STATE_FILE")"

                if [[ "$old_id" =~ ^[0-9]+$ ]]; then
                    echo "Deleting the previous Discord card..."

                    if curl -fsS --max-time 15 -X DELETE \
                        "$WEBHOOK/messages/$old_id" >/dev/null; then
                        echo "Previous card deleted."
                        rm -f "$STATE_FILE"
                    else
                        echo "WARNING: the previous card could not be deleted."
                    fi
                fi
            fi

            # Build the embed payload.
            payload=$(jq -n --arg url "$url" '{
                embeds: [{
                    title: "☁️ Cloud Access",
                    description: "Minecraft Cloud...,
                    url: $url,
                    color: 3447003,
                }]
            }')

            echo "Sending card to Discord..."

            # wait=true returns the created message including its ID.
            response=$(curl -fsS --max-time 15 \
                -H "Content-Type: application/json" \
                -d "$payload" \
                "${WEBHOOK}?wait=true") || {
                    echo "ERROR: the card could not be sent."
                    continue
                }

            message_id="$(printf '%s' "$response" | jq -r '.id // empty')"

            if [[ "$message_id" =~ ^[0-9]+$ ]]; then
                printf '%s\n' "$message_id" > "$STATE_FILE"
                echo "Card sent and its ID saved."
            else
                echo "WARNING: sent, but the ID could not be saved."
            fi
        fi
    done < <(cloudflared tunnel --no-autoupdate --url http://nextcloud:80 2>&1)

    echo "The tunnel has stopped. New attempt in 5 seconds..."
    sleep 5
done
