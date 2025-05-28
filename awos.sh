#!/usr/bin/env bash
set -euo pipefail

cardinal_direction() {
	local degrees=$1
	if (( degrees >= 337 || degrees < 23 )); then
		echo "north"
	elif (( degrees >= 23 && degrees < 68 )); then
		echo "northeast"
	elif (( degrees >= 68 && degrees < 113 )); then
		echo "east"
	elif (( degrees >= 113 && degrees < 158 )); then
		echo "southeast"
	elif (( degrees >= 158 && degrees < 203 )); then
		echo "south"
	elif (( degrees >= 203 && degrees < 248 )); then
		echo "southwest"
	elif (( degrees >= 248 && degrees < 293 )); then
		echo "west"
	elif (( degrees >= 293 && degrees < 337 )); then
		echo "northwest"
	fi
}

TIME_LOC="$(date +%H:%M)"

TEMP_F=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT temp_f FROM weather_sensor WHERE sensor_name='shed' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

WIND_DIR=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT wind_bearing FROM weather_station WHERE station_name='garden' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

WIND_MPH=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT wind_speed_mph FROM weather_station WHERE station_name='garden' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

WIND_GUST_MPH=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT wind_gust_mph FROM weather_station WHERE station_name='garden' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

WIND_CHILL_F=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT wind_chill_f FROM weather_station WHERE station_name='garden' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

HUMIDITY=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT humidity FROM weather_sensor WHERE sensor_name='shed' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

UV_IDX=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT uv FROM weather_station WHERE station_name='garden' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

PRESSURE=$(printf "%.2f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT pressure_inHg FROM aranet WHERE aranet_name='office' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

# Get pressure from 3 hours ago for trend calculation
PRESSURE_3H_AGO=$(printf "%.2f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT pressure_inHg FROM aranet WHERE aranet_name='office' AND time < now() - 3h ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

# Calculate pressure trend
PRESSURE_DIFF=$(printf "%.2f" "$(echo "$PRESSURE - $PRESSURE_3H_AGO" | bc)")
if (( $(echo "$PRESSURE_DIFF > 0.02" | bc -l) )); then
	PRESSURE_TREND="rising"
elif (( $(echo "$PRESSURE_DIFF < -0.02" | bc -l) )); then
	PRESSURE_TREND="falling"
else
	PRESSURE_TREND="steady"
fi

CLOUDCOVER=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT cloud_cover FROM weather WHERE latitude='42.367' AND longitude='-84.011' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

FEELSLIKE=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT feels_like_f FROM weather WHERE latitude='42.367' AND longitude='-84.011' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

VISIBILITY=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT visibility_mi FROM weather WHERE latitude='42.367' AND longitude='-84.011' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

STORM_DISTANCE=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT storm_distance_mi FROM weather_sensor WHERE sensor_name='shed' ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

# Get storm distance from 5 minutes ago to check if it's changing
STORM_DISTANCE_5M_AGO=$(printf "%.0f" "$(
	curl -sSL -XPOST http://jetstream.dzhome:8086/query?db=dzhome \
		--header "Accept: application/json" \
		--data-urlencode "q=SELECT storm_distance_mi FROM weather_sensor WHERE sensor_name='shed' AND time < now() - 5m ORDER BY time DESC LIMIT 1" \
		| jq '.results[0].series[0].values[0][1]'
	)"
)

# Only report storms if the distance is changing (indicating active detection)
if [ "$STORM_DISTANCE" != "$STORM_DISTANCE_5M_AGO" ]; then
	if [ "$STORM_DISTANCE" -le 5 ]; then
		STORM_INFO="Thunderstorms nearby."
	elif [ "$STORM_DISTANCE" -le 40 ]; then
		STORM_INFO="Thunderstorms $STORM_DISTANCE miles away."
	else
		STORM_INFO=""
	fi
else
	STORM_INFO=""
fi

# TODO(cdzombak): add rain once I've written the rain accumulator service

WIND_SPEED_TEXT="$WIND_MPH $([ "$WIND_MPH" = "1" ] && echo "mile" || echo "miles") per hour"

ATIS_TXT="""
West Lake automated weather observation.
$TIME_LOC local time.
$([ ! -z "$STORM_INFO" ] && echo "$STORM_INFO." || echo "").
Wind from the $(cardinal_direction $WIND_DIR) at $WIND_SPEED_TEXT
$([ $((WIND_GUST_MPH - WIND_MPH)) -gt 2 ] && echo ", gusting to $WIND_GUST_MPH" || echo "").
Temperature $TEMP_F degrees
$([ $TEMP_F -lt 50 ] && echo ", wind chill $WIND_CHILL_F degrees" || echo "").
Humidity $HUMIDITY percent.
Feels like $FEELSLIKE degrees.
Cloud cover $CLOUDCOVER percent.
U.V. Index $UV_IDX.
Visibility $VISIBILITY miles.
Altimeter $PRESSURE , and $PRESSURE_TREND.
End of observation.
"""

say -o ./latest -v "Evan" "$ATIS_TXT"
scp -o ConnectTimeout=15 -i ~/.ssh/id_ecdsa ./latest.aiff awos@officebtns.dzhome:/home/awos/audio/latest.aiff
rm ./latest.aiff
