FROM alpine:3.22

RUN apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        samba \
        samba-common-tools \
        avahi \
        avahi-tools \
        avahi-compat-libdns_sd \
        dbus \
    && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh
COPY avahi-services/*.service /etc/avahi/services/
RUN chmod +x /entrypoint.sh

EXPOSE 137/udp 138/udp 139 445 5353/udp

ENTRYPOINT ["/entrypoint.sh"]
