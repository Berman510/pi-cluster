#!/bin/sh

# Set environment variables
RTSP_URL=${RTSP_URL:-"rtsp://10.17.84.156/ch0_0.h264"}
OUTPUT_DIR=${OUTPUT_DIR:-"/recordings"}
DURATION=${RECORD_DURATION:-300}

# Print environment variables for debugging
echo "RTSP_URL=${RTSP_URL}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"
echo "DURATION=${DURATION}"

# Loop to continuously record the RTSP stream
while true; do
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    FILENAME="${OUTPUT_DIR}/recording_${TIMESTAMP}.mp4"
    echo "Recording to $FILENAME"
    if ! ffmpeg -loglevel debug -i "${RTSP_URL}" -t "${DURATION}" -c copy "${FILENAME}" 2>&1 | tee -a /recordings/ffmpeg.log; then
        echo "FFmpeg failed, retrying in 5 seconds..."
        sleep 5
    fi
    sync
    sleep 1
done
