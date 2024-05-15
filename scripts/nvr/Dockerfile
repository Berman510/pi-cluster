FROM alpine:3.19

RUN apk add --no-cache ffmpeg

WORKDIR /app

COPY entrypoint.sh /app/

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
