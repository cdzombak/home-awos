#!/usr/bin/env bash
set -euo pipefail

cd /home/awos/audio

while true; do
  cp latest.aiff play.aiff
  aplay --device plughw:CARD=3,DEV=0 -f S16_BE -r 22050 /home/awos/audio/latest.aiff
  rm play.aiff
  sleep 2
done
