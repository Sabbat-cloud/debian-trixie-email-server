#!/bin/bash

# ==============================================================================
# Script de Configuración de Servidor de Correo para Debian 13 "Trixie"
# Automatiza la instalación y configuración de Postfix, Dovecot, OpenDKIM,
# Fail2ban y ClamAV basándose en la guía proporcionada.
# ==============================================================================

# --- PREPARACIÓN Y CONFIGURACIÓN INICIAL ---

# Salir inmediatamente si un comando falla
set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

# Comprobar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ser ejecutado como root. Usa 'sudo ./setup-mail-server.sh'${NC}" 
   exit 1
fi

# --- FUNCIONES AUXILIARES ---

# Función para realizar copias de seguridad
backup_file() {
    local filepath=$1
    if [ -f "$filepath" ]; then
        echo -e "${YELLOW}Creando copia de seguridad de $filepath...${NC}"
        cp "$filepath" "$filepath.bak_$(date +%F-%T)"
    fi
}

# --- ETAPAS DEL SCRIPT ---

# 1. VERIFICACIÓN DE DEPENDENCIAS
check_dependencies() {
    echo -e "${GREEN}=== Verificando dependencias... ===${NC}"
    local packages_to_install=()
    local required_packages=("postfix" "dovecot-core" "opendkim" "opendkim-tools" "fail2ban" "clamav" "clamav-daemon" "clamsmtp" "certbot" "dig")

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            packages_to_install+=("$pkg")
        fi
    done

    if [ ${#packages_to_install[@]} -ne 0 ]; then
        echo -e "${YELLOW}Los siguientes paquetes son necesarios: ${packages_to_install[*]}.${NC}"
        read -p "¿Deseas instalarlos ahora? (s/n): " choice
        case "$choice" in
            s|S )
                apt update && apt install -y "${packages_to_install[@]}"
                ;;
            * )
                echo -e "${RED}Instalación cancelada. El script no puede continuar.${NC}"
                exit 1
                ;;
        esac
    else
        echo "Todas las dependencias están instaladas."
    fi
}

# 2. OBTENER DATOS DEL USUARIO
get_user_input() {
    echo -e "\n${GREEN}=== Introduce los datos de configuración ===${NC}"
    read -p "Introduce tu dominio (ej. tudominio.com): " DOMAIN
    read -p "Introduce la IP pública estática de este servidor: " PUBLIC_IP
    read -p "Introduce un nombre de usuario para la primera cuenta de correo (no uses 'root'): " FIRST_USER

    if [ -z "$DOMAIN" ] || [ -z "$PUBLIC_IP" ] || [ -z "$FIRST_USER" ]; then
        echo -e "${RED}Todos los campos son obligatorios. Abortando.${NC}"
        exit 1
    fi

    FQDN="mail.$DOMAIN"
    DKIM_SELECTOR="dkim2025" # Puedes cambiar esto si lo deseas
}

# 3. CONFIGURAR HOSTNAME Y FIREWALL
setup_system() {
    echo -e "\n${GREEN}=== Configurando Hostname, /etc/hosts y Firewall ===${NC}"
    
    # Hostname
    hostnamectl set-hostname "$FQDN"
    
    # /etc/hosts
    backup_file /etc/hosts
    # Eliminar cualquier línea antigua con la misma IP para evitar duplicados
    sed -i "/^$PUBLIC_IP/d" /etc/hosts
    echo "$PUBLIC_IP $FQDN mail" >> /etc/hosts
    echo "Hostname y /etc/hosts configurados."

    # Firewall (UFW)
    echo "Configurando UFW..."
    ufw allow 22/tcp  # SSH
    ufw allow 25/tcp  # SMTP
    ufw allow 587/tcp # Submission
    ufw allow 993/tcp # IMAPS
    ufw enable
}

# 4. CONFIGURAR FAIL2BAN
configure_fail2ban() {
    echo -e "\n${GREEN}=== Configurando Fail2ban ===${NC}"
    backup_file /etc/fail2ban/jail.local
    
    cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime = 1h
findtime = 10m
maxretry = 5

[postfix]
enabled = true
port = smtp,ssmtp,submission,465,25
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps
logpath = /var/log/mail.log
EOF
    echo "Fail2ban configurado."
}

# 5. OBTENER CERTIFICADO SSL
get_ssl() {
    echo -e "\n${GREEN}=== Obteniendo certificado SSL con Certbot ===${NC}"
    echo "Certbot se ejecutará en modo 'standalone'. Asegúrate de que los puertos 80 y 443 estén libres."
    read -p "Pulsa Enter para continuar..."

    certbot certonly --standalone -d "$FQDN" --non-interactive --agree-tos -m "admin@$DOMAIN"
    
    # Crear hook de renovación
    local hook_path="/etc/letsencrypt/renewal-hooks/deploy/restart-mail.sh"
    mkdir -p "$(dirname "$hook_path")"
    
    cat <<EOF > "$hook_path"
#!/bin/sh
# Reiniciar servicios de correo para cargar el nuevo certificado
systemctl restart postfix
systemctl restart dovecot
EOF

    chmod +x "$hook_path"
    echo "Certificado SSL obtenido y hook de renovación creado."
}

# 6. CONFIGURAR POSTFIX
configure_postfix() {
    echo -e "\n${GREEN}=== Configurando Postfix ===${NC}"
    backup_file /etc/postfix/main.cf
    backup_file /etc/postfix/master.cf
    
    # Configurar main.cf
    cat <<EOF > /etc/postfix/main.cf
# --- Identidad del Servidor ---
myhostname = $FQDN
mydomain = $DOMAIN
myorigin = \$mydomain

# --- Destinos y Redes ---
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
relayhost =

# --- Formato de Buzón ---
home_mailbox = Maildir/

# --- Banner SMTP ---
smtpd_banner = \$myhostname ESMTP

# --- Configuración TLS (Let's Encrypt) ---
smtpd_tls_cert_file = /etc/letsencrypt/live/$FQDN/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/$FQDN/privkey.pem
smtpd_tls_security_level = may
smtp_tls_security_level = may

# --- Autenticación SASL (vía Dovecot) ---
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname

# --- Restricciones de Envío ---
smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

# --- Integración con OpenDKIM ---
milter_default_action = accept
milter_protocol = 4
smtpd_milters = inet:localhost:8891
non_smtpd_milters = \$smtpd_milters

# --- Entrega Local a Dovecot vía LMTP ---
mailbox_transport = lmtp:unix:private/dovecot-lmtp

# --- Integración con ClamAV ---
content_filter = smtp:[127.0.0.1]:10024
receive_override_options = no_address_mappings

# --- Alias ---
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
EOF

    # Configurar master.cf (descomentar y configurar submission y smtps)
    sed -i -E \
        -e 's/^#(submission .* smtpd)/\1/' \
        -e '/^submission/a \  -o syslog_name=postfix/submission\n  -o smtpd_tls_security_level=encrypt\n  -o smtpd_sasl_auth_enable=yes\n  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject' \
        -e 's/^#(smtps .* smtpd)/\1/' \
        -e '/^smtps/a \  -o syslog_name=postfix/smtps\n  -o smtpd_tls_wrappermode=yes\n  -o smtpd_sasl_auth_enable=yes\n  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject' \
        /etc/postfix/master.cf
    
    echo "Postfix configurado."
}

# 7. CONFIGURAR DOVECOT
configure_dovecot() {
    echo -e "\n${GREEN}=== Configurando Dovecot ===${NC}"

    # 10-mail.conf
    local mail_conf="/etc/dovecot/conf.d/10-mail.conf"
    backup_file "$mail_conf"
    sed -i 's/^#?mail_location = .*/mail_location = maildir:~\/Maildir\//' "$mail_conf"
    
    # 10-auth.conf
    local auth_conf="/etc/dovecot/conf.d/10-auth.conf"
    backup_file "$auth_conf"
    sed -i 's/^#?disable_plaintext_auth = .*/disable_plaintext_auth = yes/' "$auth_conf"
    sed -i 's/^#?auth_mechanisms = .*/auth_mechanisms = plain login/' "$auth_conf"

    # 10-master.conf
    local master_conf="/etc/dovecot/conf.d/10-master.conf"
    backup_file "$master_conf"
    sed -i '/service auth {/a \    unix_listener \/var\/spool\/postfix\/private\/auth {\n      mode = 0666\n      user = postfix\n      group = postfix\n    }' "$master_conf"
    sed -i '/service lmtp {/a \  unix_listener \/var\/spool\/postfix\/private\/dovecot-lmtp {\n    mode = 0600\n    user = postfix\n    group = postfix\n  }' "$master_conf"

    # 10-ssl.conf
    local ssl_conf="/etc/dovecot/conf.d/10-ssl.conf"
    backup_file "$ssl_conf"
    sed -i 's/^#?ssl = .*/ssl = required/' "$ssl_conf"
    sed -i "s|^#?ssl_cert = .*|ssl_cert = </etc/letsencrypt/live/$FQDN/fullchain.pem|" "$ssl_conf"
    sed -i "s|^#?ssl_key = .*|ssl_key = </etc/letsencrypt/live/$FQDN/privkey.pem|" "$ssl_conf"
    
    echo "Dovecot configurado."
}

# 8. CONFIGURAR CLAMAV
configure_clamav() {
    echo -e "\n${GREEN}=== Configurando ClamAV ===${NC}"

    # Configurar clamsmtpd.conf
    local clamsmtp_conf="/etc/clamsmtpd.conf"
    backup_file "$clamsmtp_conf"
    cat <<EOF > "$clamsmtp_conf"
OutAddress: 10025
Listen: 127.0.0.1:10024
ClamAddress: /var/run/clamav/clamd.ctl
TempDirectory: /var/spool/clamsmtp
PidFile: /var/run/clamsmtp/clamsmtpd.pid
User: clamsmtp
EOF

    # Añadir servicio de re-inyección a master.cf de Postfix
    local master_cf="/etc/postfix/master.cf"
    cat <<EOF >> "$master_cf"

# --- Interfaz para recibir correo ya escaneado por ClamAV ---
127.0.0.1:10025 inet n - n - - smtpd
  -o content_filter=
  -o receive_override_options=no_unknown_recipient_checks,no_header_body_checks
  -o smtpd_helo_restrictions=
  -o smtpd_sender_restrictions=
  -o smtpd_recipient_restrictions=permit_mynetworks,reject
  -o mynetworks=127.0.0.0/8
  -o smtpd_authorized_clients=127.0.0.0/8
  -o smtpd_tls_security_level=none
  -o smtpd_sasl_auth_enable=no
EOF
    echo "ClamAV configurado."
}


# 9. CONFIGURAR OPENDKIM
configure_opendkim() {
    echo -e "\n${GREEN}=== Configurando OpenDKIM ===${NC}"
    
    # Crear directorios y claves
    mkdir -p "/etc/opendkim/keys/$DOMAIN"
    opendkim-genkey -b 2048 -d "$DOMAIN" -D "/etc/opendkim/keys/$DOMAIN" -s "$DKIM_SELECTOR"
    chown -R opendkim:opendkim /etc/opendkim/keys
    chmod 600 "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private"
    
    # Configurar opendkim.conf
    local opendkim_conf="/etc/opendkim.conf"
    backup_file "$opendkim_conf"
    cat <<EOF > "$opendkim_conf"
Syslog                  yes
UMask                   002
Socket                  inet:8891@localhost
Mode                    sv
Canonicalization        relaxed/simple
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
EOF

    # Crear ficheros de mapeo
    echo "$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.private" > /etc/opendkim/KeyTable
    echo "*@$DOMAIN $DKIM_SELECTOR._domainkey.$DOMAIN" > /etc/opendkim/SigningTable
    echo -e "127.0.0.1\nlocalhost\n*.$DOMAIN" > /etc/opendkim/TrustedHosts

    echo "OpenDKIM configurado."
}

# 10. CREAR USUARIO Y REINICIAR SERVICIOS
finalize_setup() {
    echo -e "\n${GREEN}=== Finalizando la configuración ===${NC}"

    # Crear primer usuario
    local password=$(openssl rand -base64 12)
    adduser --disabled-password --gecos "" "$FIRST_USER"
    echo "$FIRST_USER:$password" | chpasswd
    echo "Usuario '$FIRST_USER' creado."

    # Reiniciar servicios en orden
    echo "Reiniciando servicios..."
    systemctl restart clamav-daemon
    systemctl restart clamsmtp
    systemctl restart opendkim
    systemctl restart postfix
    systemctl restart dovecot
    systemctl restart fail2ban

    # Habilitar servicios
    systemctl enable opendkim postfix dovecot fail2ban clamav-daemon clamsmtp

    # Resumen final
    echo -e "\n\n${GREEN}=====================================================${NC}"
    echo -e "${GREEN}      🎉 ¡CONFIGURACIÓN DEL SERVIDOR COMPLETADA! 🎉      ${NC}"
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "\n${YELLOW}--- ACCIONES MANUALES REQUERIDAS ---${NC}"
    echo "1.  **Configura el registro PTR (DNS Inverso)** con tu proveedor de hosting:"
    echo "    IP:   $PUBLIC_IP"
    echo "    Debe apuntar a: $FQDN"
    echo ""
    echo "2.  **Añade el siguiente registro TXT para DKIM en tu panel de DNS**:"
    echo -e "${YELLOW}-----------------------------------------------------${NC}"
    cat "/etc/opendkim/keys/$DOMAIN/$DKIM_SELECTOR.txt"
    echo -e "${YELLOW}-----------------------------------------------------${NC}"
    echo ""
    echo -e "${YELLOW}--- DATOS DE LA PRIMERA CUENTA DE CORREO ---${NC}"
    echo "    Usuario:    $FIRST_USER@$DOMAIN"
    echo "    Contraseña: $password"
    echo "    Servidor IMAP: $FQDN (Puerto 993, SSL/TLS)"
    echo "    Servidor SMTP: $FQDN (Puerto 587, STARTTLS)"
    echo ""
    echo "Recuerda que la propagación del DNS puede tardar varias horas."
    echo "Usa https://www.mail-tester.com/ para verificar tu configuración."
}


# --- EJECUCIÓN DEL SCRIPT ---
main() {
    check_dependencies
    get_user_input
    setup_system
    configure_fail2ban
    get_ssl
    configure_postfix
    configure_dovecot
    configure_clamav
    configure_opendkim
    finalize_setup
}

main
