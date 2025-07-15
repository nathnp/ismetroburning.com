#!/bin/bash

cd /home/private/IMB

source ".env"

API_KEY="${WMATA_API_KEY}"
API_URL="https://api.wmata.com/Incidents.svc/json/Incidents"
OUTPUT_FILE="data/metro_status.json"

LINES=("RD" "OR" "BL" "YL" "GR" "SV")

if [ "$NFSN_SITE_NAME" = "imbprod" ]; then

	# Fetch incidents from WMATA
	RESPONSE=$(curl -s -H "api_key: $API_KEY" "$API_URL")

	# Start the JSON object
	echo "{" > "$OUTPUT_FILE"

	# Track line count to avoid trailing comma
	COUNT=0
	TOTAL=${#LINES[@]}

	for LINE in "${LINES[@]}"; do
		INCIDENT=$(echo "$RESPONSE" | jq -r --arg LINE "$LINE" '
			.Incidents[] | select(.LinesAffected | contains($LINE)) |
			select(.Description | test("fire|smoke|burning"; "i")) |
			.Description
		' | head -n 1)

		if [[ -n "$INCIDENT" ]]; then
			FIRE_STATUS=true
			MESSAGE=$(echo "$INCIDENT" | jq -R -s '.')  # Proper JSON-escaped string
		else
			FIRE_STATUS=false
			MESSAGE='""'
		fi

		COUNT=$((COUNT + 1))
	
		# Append comma only if it's not the last item
		if [[ $COUNT -lt $TOTAL ]]; then
			echo "  \"$LINE\": {\"fire\": $FIRE_STATUS, \"message\": $MESSAGE}," >> "$OUTPUT_FILE"
		else
			echo "  \"$LINE\": {\"fire\": $FIRE_STATUS, \"message\": $MESSAGE}" >> "$OUTPUT_FILE"
		fi
		done

		# Close the JSON object
		echo "}" >> "$OUTPUT_FILE"

else
	echo "Not Prod, skipping API Pull"	
fi

# Actions Logic

CURRENT="data/metro_status.json"
PREVIOUS="data/metro_status_prv.json"

PRIV_NTFY="${PRIV_NTFY}"
DISCORD_HOOK="${DISCORD_HOOK}"
MASTO_KEY="${MASTO_KEY}"

for LINE in "${LINES[@]}"; do
  CURRENT_STATUS=$(jq -r --arg l "$LINE" '.[$l].fire' "$CURRENT")
  PREVIOUS_STATUS=$(jq -r --arg l "$LINE" '.[$l].fire' "$PREVIOUS")
  CURRENT_MESSAGE=$(jq -r --arg l "$LINE" '.[$l].message' "$CURRENT")
  PREVIOUS_MESSAGE=$(jq -r --arg l "$LINE" '.[$l].message' "$PREVIOUS")

  if [[ "$CURRENT_STATUS" == "true" && "$PREVIOUS_STATUS" != "true" ]]; then
  
  	MESSAGE=$(jq -r --arg l "$LINE" '.[$l].message' "$CURRENT")
  
    curl -d "🔥 New incident on $LINE line: $MESSAGE" "$PRIV_NTFY"
	
	postSlug=$(date +"%Y%m%d-%H%M")
	pepper=$(date | md5sum | head -c 4)
	
	./hugo new content fire/$postSlug\-$pepper/index.md
	
	echo "" >> content/fire/$postSlug\-$pepper/index.md
	echo "🔥 New incident on $LINE line: $MESSAGE" >> content/fire/$postSlug\-$pepper/index.md
	
	
	# Only runs if on prod
	if [ "$NFSN_SITE_NAME" = "imbprod" ]; then
	
		#WMATA Discord
		curl -H "Content-Type: application/json" \
		 -X POST \
		 -d "{\"content\":\"🔥 New incident on $LINE line: $MESSAGE\"}" \
		 $DISCORD_HOOK
		 
		 #Mastodon		 
		 MASTODON_INSTANCE="https://mastodon.social"
		 ACCESS_TOKEN="$MASTO_KEY"
		 
		 curl -s -X POST "$MASTODON_INSTANCE/api/v1/statuses" \
		   -H "Authorization: Bearer $ACCESS_TOKEN" \
		   -d "status=🔥 New incident on $LINE line: $MESSAGE"
		   
		 #BSky
		 python3 bsky.py "🔥 New incident on $LINE line: $MESSAGE"
		 
		 #X
		 python3 x.py "🔥 New incident on $LINE line: $MESSAGE"
		 
		 echo "{\"unixtime\": $(date +%s)}" > data/lastInct.json

	fi
		
	sleep 1
    
  fi
  
  CURRENT_CLEAN=$(echo "$CURRENT_MESSAGE" | tr -d '\n' | xargs)
  PREVIOUS_CLEAN=$(echo "$PREVIOUS_MESSAGE" | tr -d '\n' | xargs)
  if [[ "$CURRENT_STATUS" == "true" && "$PREVIOUS_STATUS" == "true" && "$CURRENT_CLEAN" != "$PREVIOUS_CLEAN" ]]; then
  
  	MESSAGE=$(jq -r --arg l "$LINE" '.[$l].message' "$CURRENT")
  
  	curl -d "Update on $LINE line: $MESSAGE" "$PRIV_NTFY"
	  
	postSlug=$(date +"%Y%m%d-%H%M")
	pepper=$(date | md5sum | head -c 4)
	
	./hugo new content fire/$postSlug\-$pepper/index.md
	
	echo "" >> content/fire/$postSlug\-$pepper/index.md
	echo "Update on $LINE line: $MESSAGE" >> content/fire/$postSlug\-$pepper/index.md
	
	
	# Only runs if on prod
	if [ "$NFSN_SITE_NAME" = "imbprod" ]; then
	
		#WMATA Discord
		curl -H "Content-Type: application/json" \
		 -X POST \
		 -d "{\"content\":\"Update on $LINE line: $MESSAGE\"}" \
		 $DISCORD_HOOK
		 
		 #Mastodon		 
		 MASTODON_INSTANCE="https://mastodon.social"
		 ACCESS_TOKEN="$MASTO_KEY"
		 
		 curl -s -X POST "$MASTODON_INSTANCE/api/v1/statuses" \
		   -H "Authorization: Bearer $ACCESS_TOKEN" \
		   -d "status=Update on $LINE line: $MESSAGE"
		   
		 #BSky
		 python3 bsky.py "Update on $LINE line: $MESSAGE"
		 
		 #X
		 python3 x.py "Update on $LINE line: $MESSAGE"
	
	fi
		
	sleep 1
  
  fi
  

done

cp data/metro_status.json data/metro_status_prv.json

# Destination directory
DEST_DIR="/home/logs/fire"

# Timestamp in format: yyyymmdd-hhmm
TIMESTAMP=$(date +"%Y%m%d-%H%M")

# Output file path
DEST_FILE="$DEST_DIR/metro_status_$TIMESTAMP.json"

# Copy the file with the timestamped name
cp data/metro_status.json "$DEST_FILE"

./hugo -d /home/public