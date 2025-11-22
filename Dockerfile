FROM alpine:edge

RUN apk update && apk add --no-cache \
    samba \
    samba-common-tools \
    avahi \
    avahi-tools \
    avahi-compat-libdns_sd \
    dbus

COPY entrypoint.sh /entrypoint.sh
COPY avahi-services/*.service /etc/avahi/services/
RUN chmod +x /entrypoint.sh

EXPOSE 137/udp 138/udp 139 445 5353/udp

ENTRYPOINT ["/entrypoint.sh"]
