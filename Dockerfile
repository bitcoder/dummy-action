FROM debian:9.5-slim

WORKDIR /
COPY . /

RUN apt update && apt install -y curl

ADD xray_import_results.sh /xray_import_results.sh
ENTRYPOINT ["/xray_import_results.sh"]
