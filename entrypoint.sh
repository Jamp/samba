#!/bin/sh
addgroup smb

# Start D-Bus (required by Avahi)
mkdir -p /var/run/dbus
rm -f /var/run/dbus/pid
dbus-daemon --system --fork

# Get netbios/hostname for Avahi (use NETBIOS_NAME, fallback to WORKGROUP, then default)
avahi_hostname="${NETBIOS_NAME:-${WORKGROUP:-samba-server}}"

# Configure Avahi
sed -i 's/#enable-dbus=yes/enable-dbus=yes/g' /etc/avahi/avahi-daemon.conf
sed -i 's/#host-name=.*/host-name='${avahi_hostname}'/g' /etc/avahi/avahi-daemon.conf

# Start Avahi daemon
avahi-daemon --daemonize --no-chroot

# Wait for Avahi to start
sleep 2

workgroup="${WORKGROUP:-'WORKGROUP'}"
netbios_name="${NETBIOS_NAME:-$workgroup}"

# Crea el archivo de configuración de Samba
cat <<EOF > /etc/samba/smb.conf
[global]
    netbios name = $netbios_name
    server string = Samba Server of $workgroup
    workgroup = $workgroup
    server role = standalone server
    log file = /dev/stdout
    log level = 2
    syslog = 2
    
    # Avahi/Bonjour support
    multicast dns register = yes
    
    # macOS compatibility
    min protocol = SMB2
    ea support = yes
    vfs objects = catia fruit streams_xattr
    fruit:metadata = stream
    fruit:model = MacSamba
    fruit:posix_rename = yes
    fruit:veto_appledouble = no
    fruit:nfs_aces = no
    fruit:wipe_intentionally_left_blank_rfork = yes
    fruit:delete_empty_adfiles = yes

    force group = smb
    follow symlinks = yes
    
    # Performance
    socket options = TCP_NODELAY SO_RCVBUF=524288 SO_SNDBUF=524288
    use sendfile = yes
    aio read size = 1
    aio write size = 1
    
    # Security
    client ipc max protocol = SMB3
    client ipc min protocol = SMB2_10
    client max protocol = SMB3
    client min protocol = SMB2_10
    server max protocol = SMB3
    server min protocol = SMB2_10

EOF

# Agregar usuarios y directorios personalizados si se especifican
USERS=$(echo "$USERS" | tr ',' '\n')
VALID_USERS=""
for user in $USERS; do
    username=$(echo $user | cut -d':' -f1)
    password=$(echo $user | cut -d':' -f2)
    home_dir="/${username}"

    # Construir lista de usuarios válidos
    VALID_USERS="$VALID_USERS $username"

    # Crea un directorio de usuario
    mkdir -p $home_dir
    chmod -R 770 $home_dir
    adduser -D $username
    addgroup $username smb
    chown -R $username:$username $home_dir

    # Agrega el usuario a Samba
    echo -e "$password\n$password" | smbpasswd -a -s $username

    # Agrega el share del usuario al archivo de configuración de Samba
    cat <<EOF >> /etc/samba/smb.conf
[$username]
    path = $home_dir
    browsable = yes
    writable = yes
    guest ok = no
    create mask = 0770
    directory mask = 0770
    veto files = /.apdisk/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/
    delete veto files = yes
    valid users = $username

EOF
done

if [ "$ENABLE_PUBLIC" = "true" ]; then
    mkdir -p /public
    chmod 777 /public
    
    cat <<EOF >> /etc/samba/smb.conf
[public]
    path = /public
    browsable = yes
    writable = yes
    guest ok = yes
    force user = nobody
    force group = nogroup
    create mask = 0777
    directory mask = 0777
    veto files = /.apdisk/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/
    delete veto files = yes

EOF
fi

if [ "$ENABLE_TIMEMACHINE" = "true" ]; then
    mkdir -p /timemachine
    chmod -R 770 /timemachine
    
    # Set quota if specified (in GB)
    TM_SIZE="${TM_SIZE:-0}"
    
    cat <<EOF >> /etc/samba/smb.conf
[TimeMachine]
    path = /timemachine
    browsable = yes
    writable = yes
    guest ok = no
    create mask = 0600
    directory mask = 0700
    
    # Time Machine specific settings
    vfs objects = catia fruit streams_xattr
    fruit:time machine = yes
    fruit:time machine max size = ${TM_SIZE}G
    fruit:advertise_fullsync = yes
    
    # macOS metadata
    fruit:metadata = stream
    fruit:locking = netatalk
    fruit:encoding = native
    
    valid users = $VALID_USERS

EOF

    # Reload Avahi to pickup the Time Machine service
    if [ -f /etc/avahi/services/timemachine.service ]; then
        killall -HUP avahi-daemon 2>/dev/null || true
    fi
fi

# Test configuration
testparm -s

# Inicia Samba
exec smbd --foreground --no-process-group
