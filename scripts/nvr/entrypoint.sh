#!/bin/sh

echo "RTSP_URL=${RTSP_URL}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"
echo "DURATION=${RECORD_DURATION}"

RTSP_URL=${RTSP_URL:-"rtsp://10.17.84.156/ch0_0.h264"}
OUTPUT_DIR=${OUTPUT_DIR:-"/recordings"}
DURATION=${RECORD_DURATION:-300}

while true; do
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    FILENAME="$OUTPUT_DIR/recording_$TIMESTAMP.mp4"
    echo "Recording to $FILENAME"
    ffmpeg -loglevel debug -i "$RTSP_URL" -t "$DURATION" -c copy "$FILENAME" 2>&1 | tee -a /recordings/ffmpeg.log
    sleep 1
done
