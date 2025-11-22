FROM alpine:edge

RUN apk update && apk add --no-cache \
    samba \
    samba-common-tools \
    avahi \
    dbus

COPY entrypoint.sh /entrypoint.sh
COPY avahi-services/smb.service /etc/avahi/services/smb.service
RUN chmod +x /entrypoint.sh

EXPOSE 137/udp 138/udp 139 445 5353/udp

ENTRYPOINT ["/entrypoint.sh"]
