#!/bin/sh

# Set environment variables
RTSP_URL=${RTSP_URL:-"rtsp://10.17.84.156/ch0_0.h264"}
OUTPUT_DIR=${OUTPUT_DIR:-"/recordings"}
DURATION=${RECORD_DURATION:-300}

#!/bin/sh

echo "RTSP_URL=${RTSP_URL}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"
echo "DURATION=${DURATION}"

if [ -z "$RTSP_URL" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$DURATION" ]; then
    echo "Required environment variables are missing"
    exit 1
fi

OUTPUT_FILE="${OUTPUT_DIR}/recording_$(date +"%Y%m%d%H%M%S").mp4"
echo "Recording to ${OUTPUT_FILE}"

ffmpeg -loglevel debug -analyzeduration 10000000 -probesize 10000000 -i "$RTSP_URL" -t "$DURATION" -c copy "$OUTPUT_FILE"
