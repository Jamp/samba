FROM alpine:edge

RUN apk update && apk add --no-cache samba samba-common-tools

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 137/udp 138/udp 139 445

ENTRYPOINT ["/entrypoint.sh"]
