#!/bin/sh

RTSP_URL=${RTSP_URL:-"rtsp://10.17.84.156/ch0_0.h264"}
OUTPUT_DIR=${OUTPUT_DIR:-"/recordings"}
DURATION=${RECORD_DURATION:-300}

while true; do
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    FILENAME="$OUTPUT_DIR/recording_$TIMESTAMP.mp4"
    ffmpeg -i "$RTSP_URL" -t "$DURATION" -c copy "$FILENAME"
    sleep 1
done
