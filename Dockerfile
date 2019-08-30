FROM debian:9.5-slim

WORKDIR /
COPY . /

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
