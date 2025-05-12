FROM alpine:3.20 as alpine

ARG POSTGRES_VERSION
RUN apk add --no-cache postgresql$POSTGRES_VERSION-client \
      aws-cli \
      curl \
      bash

WORKDIR /scripts

COPY backup.sh .
ENTRYPOINT [ "/scripts/backup.sh" ]
