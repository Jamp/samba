#!/bin/sh
addgroup smb

workgroup="${WORKGROUP:-'WORKGROUP'}"

# Crea el archivo de configuración de Samba
cat <<EOF > /etc/samba/smb.conf
[global]
    server string = Samba Server of $workgroup
    workgroup = $workgroup
    server role = standalone server
    log file = /dev/stdout
    log level = 2
    log file = /dev/stdout
    syslog = 2
    # max log size = 50
    # pam password change = yes
    # map to guest = bad user
    # usershare allow guests = yes

    force group = smb
    follow symlinks = yes
    aio read size = 0
    aio write size = 0
    vfs objects = catia fruit recycle streams_xattr

    # Security
    client ipc max protocol = SMB3
    client ipc min protocol = SMB2_10
    client max protocol = SMB3
    client min protocol = SMB2_10
    server max protocol = SMB3
    server min protocol = SMB2_10

    # Time Machine
    fruit:delete_empty_adfiles = yes
    fruit:time machine = yes
    fruit:veto_appledouble = no
    fruit:wipe_intentionally_left_blank_rfork = yes

EOF

# Agregar usuarios y directorios personalizados si se especifican
USERS=$(echo "$USERS" | tr ',' '\n')
for user in $USERS; do
    username=$(echo $user | cut -d':' -f1)
    password=$(echo $user | cut -d':' -f2)
    home_dir="/${username}"

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

# Inicia Samba
exec smbd --foreground --no-process-group
