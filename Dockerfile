FROM debian:9.5-slim

WORKDIR /
COPY . /

RUN apt update && apt install -y curl

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
