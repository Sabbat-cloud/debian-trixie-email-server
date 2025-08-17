# Guía Completa para Configurar un Servidor de Correo en Debian 13 "Trixie" 📧

Un servidor de correo permite enviar y recibir correos electrónicos desde tu propio dominio (por ejemplo, `tunombre@tu-dominio.com`). Es ideal para empresas, proyectos personales o para aprender sobre la infraestructura de correo. Esta guía te ayudará a configurar un servidor seguro y funcional en Debian 13.

Instalar un servidor de correo funcional y seguro es un proceso que requiere atención al detalle. Esta guía te llevará paso a paso a través de la configuración de un servidor de correo moderno y robusto en **Debian 13**. Cubriremos desde los requisitos previos y la configuración crítica del DNS hasta la instalación y configuración del software esencial.

### ⚙️ **Componentes Principales**

  * **Sistema Operativo:** Debian 13 "Trixie"
  * **MTA (Agente de Transferencia):** Postfix
  * **Servidor IMAP/POP3:** Dovecot
  * **Firma de Correo (Autenticación):** OpenDKIM
  * **Protección contra Ataques:** Fail2ban
  * **Análisis Antivirus:** ClamAV

### **Datos de Ejemplo Utilizados**

A lo largo de esta guía, reemplaza los siguientes valores con los tuyos:

  * **Dominio:** `tu-dominio.com`
  * **Hostname del Servidor (FQDN):** `mail.tu-dominio.com`
  * **IP Pública Estática:** `123.45.67.89`
  * **Selector DKIM:** `dkim2025` (puedes elegir otro, como `mail` o `key1`)

-----

## **Paso 1: Preparativos Esenciales**

Antes de instalar cualquier paquete, es fundamental tener una base sólida.

### **1.1. Requisitos del Servidor y Dominio**

  * **Un servidor:** Un VPS o servidor dedicado con una **dirección IP pública estática**.
  * **Un dominio:** Un nombre de dominio registrado (ej. `tu-dominio.com`).

### **1.2. Configuración del Hostname (FQDN)**

El nombre de tu servidor debe ser un **FQDN** (Nombre de Dominio Completamente Cualificado), como `mail.tu-dominio.com`.

1.  **Establecer el hostname:**
    ```bash
    sudo hostnamectl set-hostname mail.tu-dominio.com
    ```
2.  **Verificar el fichero `/etc/hosts`:**
    Asegúrate de que este fichero asocia tu IP pública con tu FQDN. Debería tener una línea similar a esta:
    ```
    123.45.67.89 mail.tu-dominio.com mail
    ```

### **1.3. Actualización del Sistema**

Asegúrate de que tu sistema está completamente actualizado.

```bash
sudo apt update && sudo apt upgrade -y
```

-----

## **Paso 2: Configuración Crítica del DNS** 🌐

Una configuración de DNS correcta es **la clave para que tus correos no sean marcados como spam**. Accede al panel de control de tu proveedor de dominio para configurar los siguientes registros.

### **Registro PTR (DNS Inverso) - ¡Obligatorio\!**

Este registro asocia tu IP con el nombre de tu servidor (`123.45.67.89` -\> `mail.tu-dominio.com`). **No puedes crearlo tú mismo en el panel de tu dominio**.

  * **Acción:** Debes solicitar a tu proveedor de hosting (donde tienes el servidor) que lo configure.
  * **Ejemplo de Petición:** "Por favor, configuren el registro PTR para la IP `123.45.67.89` para que apunte a `mail.tu-dominio.com`."
      * *Nota: Proveedores como IONOS, Vultr o DigitalOcean a menudo te permiten configurar esto directamente desde su panel de control del servidor.*

### **Registros en el Panel de tu Dominio**

| TIPO | NOMBRE DE HOST | VALOR / APUNTA A | FUNCIÓN |
| :--- | :--- | :--- | :--- |
| **A** | `mail` | `123.45.67.89` | Asocia el nombre del servidor de correo con su IP. |
| **MX** | `@` | `mail.tu-dominio.com` | Indica que todo el correo para `tu-dominio.com` lo gestiona tu servidor. |
| **SPF**| `@` | `v=spf1 mx -all` | Autoriza a los servidores listados en tus registros MX (es decir, tu servidor) a enviar correos. |
| **DMARC**| `_dmarc`| `v=DMARC1; p=none; rua=mailto:admin@tu-dominio.com` | Define la política de autenticación y a dónde enviar informes. |
| **DKIM** | `dkim2025._domainkey` | (Valor generado más adelante) | Contiene la clave pública para verificar la firma de tus correos. Dejaremos esto pendiente y lo completaremos en el **Paso 6**. |

**Tiempo de propagación:** Los registros DNS pueden tardar hasta 24-48 horas en propagarse. Los cambios no son inmediatos.

-----

## **Paso 3: Configuración del Firewall** 🔥

Debes abrir los puertos necesarios para que el correo pueda entrar y salir. Usa `ufw` (Uncomplicated Firewall) o el firewall de tu proveedor.

1.  **Instalar UFW (si no está presente):**

    ```bash
    sudo apt install ufw
    ```

2.  **Abrir los puertos necesarios:**

    ```bash
    # Acceso SSH (usa tu puerto personalizado si lo has cambiado)
    sudo ufw allow 22/tcp

    # SMTP (recepción de correo y envío servidor-a-servidor)
    sudo ufw allow 25/tcp

    # Submission (envío de correo de clientes como Outlook/Thunderbird)
    sudo ufw allow 587/tcp

    # IMAPS (lectura segura de correo)
    sudo ufw allow 993/tcp

    # Habilitar el firewall
    sudo ufw enable
    ```

> **¡Importante\!** Muchos proveedores de hosting bloquean el **puerto 25 saliente** por defecto para prevenir el spam. Contacta con su soporte y solicita que lo desbloqueen para tu servidor.

-----

## **Paso 4: Protección contra Ataques con Fail2ban** 🛡️

**Fail2ban** es una herramienta esencial que escanea los archivos de registro en busca de intentos fallidos de inicio de sesión o ataques de fuerza bruta. Cuando detecta una serie de intentos fallidos de una misma IP, la bloquea temporalmente en el firewall.

1.  **Instalar Fail2ban:**

    ```bash
    sudo apt install fail2ban
    ```

2.  **Crear un fichero de configuración local:**
    No edites el fichero `jail.conf` directamente. Es mejor crear un fichero `jail.local` para tus configuraciones personalizadas.

    ```bash
    sudo nano /etc/fail2ban/jail.local
    ```

3.  **Añadir las configuraciones para Postfix y Dovecot:**
    Pega el siguiente contenido en el fichero. Esto activará la protección para los intentos de inicio de sesión en tus servicios de correo y los intentos de conexión al servidor SMTP.

    ```ini
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
    ```

      * `bantime`: Duración del bloqueo (en este caso, 1 hora).
      * `findtime`: Período de tiempo para contar los intentos fallidos (en este caso, 10 minutos).
      * `maxretry`: Número de intentos fallidos antes de bloquear la IP (en este caso, 5).

4.  **Reiniciar el servicio de Fail2ban:**

    ```bash
    sudo systemctl restart fail2ban
    ```

-----

## **Paso 5: Certificados SSL/TLS con Let's Encrypt** 🔐

Para cifrar las comunicaciones y asegurar que tu servidor es de confianza, usaremos certificados gratuitos de Let's Encrypt.

1.  **Instalar Certbot:**

    ```bash
    sudo apt install certbot
    ```

2.  **Obtener el certificado:**
    Usaremos el método `standalone`, que inicia un pequeño servidor web temporal para la validación. Asegúrate de que los puertos 80 y 443 no estén en uso por otro servicio.

    ```bash
    sudo certbot certonly --standalone -d mail.tu-dominio.com
    ```

    Sigue las instrucciones en pantalla (introduce tu email y acepta los términos).

3.  **Verificar los archivos:**
    Tus certificados se guardarán en `/etc/letsencrypt/live/mail.tu-dominio.com/`. Los dos archivos que usaremos son:

      * `fullchain.pem` (tu certificado + la cadena de confianza)
      * `privkey.pem` (tu clave privada)

4.  **Configurar la renovación automática:**
    Certbot crea un temporizador de `systemd` que renueva los certificados automáticamente. Para que Postfix y Dovecot usen el nuevo certificado tras la renovación, debemos crear un "hook".

    Crea el siguiente script:

    ```bash
    sudo nano /etc/letsencrypt/renewal-hooks/deploy/restart-mail.sh
    ```

    Añade este contenido:

    ```bash
    #!/bin/sh
    # Reiniciar servicios de correo para cargar el nuevo certificado

    systemctl restart postfix
    systemctl restart dovecot
    ```

    Hazlo ejecutable:

    ```bash
    sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-mail.sh
    ```

-----

## **Paso 6: Instalación y Configuración del Software de Correo** 📦

Ahora instalaremos y configuraremos el corazón de nuestro servidor.

### **6.1. Instalación de Paquetes**

```bash
sudo apt update
sudo apt install postfix dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools dig
```

Durante la instalación de Postfix:

  * En la primera pantalla, selecciona **Sitio de Internet**.
  * En la segunda, introduce tu nombre de dominio: `tu-dominio.com`.

### **6.2. Configuración de Postfix** 📬

**Postfix** se encarga de enviar y recibir los correos.

1.  **Haz una copia de seguridad de los ficheros originales:**

    ```bash
    sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
    sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.bak
    ```

2.  **Edita `/etc/postfix/main.cf`:**
    Reemplaza su contenido con esta configuración, adaptándola a tus datos.

    ```ini
    # --- Identidad del Servidor ---
    myhostname = mail.tu-dominio.com
    mydomain = tu-dominio.com
    myorigin = $mydomain

    # --- Destinos y Redes ---
    mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
    mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
    relayhost =

    # --- Formato de Buzón ---
    home_mailbox = Maildir/

    # --- Banner SMTP ---
    smtpd_banner = $myhostname ESMTP

    # --- Configuración TLS (Let's Encrypt) ---
    smtpd_tls_cert_file = /etc/letsencrypt/live/mail.tu-dominio.com/fullchain.pem
    smtpd_tls_key_file = /etc/letsencrypt/live/mail.tu-dominio.com/privkey.pem
    smtpd_tls_security_level = may
    smtp_tls_security_level = may

    # --- Autenticación SASL (vía Dovecot) ---
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable = yes
    smtpd_sasl_security_options = noanonymous
    smtpd_sasl_local_domain = $myhostname

    # --- Restricciones de Envío ---
    smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

    # --- Integración con OpenDKIM ---
    milter_default_action = accept
    milter_protocol = 4
    smtpd_milters = inet:localhost:8891
    non_smtpd_milters = $smtpd_milters

    # --- Entrega Local a Dovecot vía LMTP ---
    mailbox_transport = lmtp:unix:private/dovecot-lmtp

    # --- Alias ---
    alias_maps = hash:/etc/aliases
    alias_database = hash:/etc/aliases
    ```

3.  **Edita `/etc/postfix/master.cf`:**
    Asegúrate de que las secciones `submission` (puerto 587) y `smtps` (puerto 465) están descomentadas y configuradas para usar la autenticación SASL. Busca estas líneas al principio del fichero y modifícalas o añádelas:

    ```
    submission inet n       -       y       -       -       smtpd
      -o syslog_name=postfix/submission
      -o smtpd_tls_security_level=encrypt
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_relay_restrictions=permit_sasl_authenticated,reject

    smtps       inet  n       -       y       -       -       smtpd
      -o syslog_name=postfix/smtps
      -o smtpd_tls_wrappermode=yes
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
    ```

### **6.3. Configuración de Dovecot** 📥

**Dovecot** permite a los usuarios acceder a sus buzones de correo a través de IMAP.

Realizaremos cambios en varios ficheros de configuración dentro de `/etc/dovecot/conf.d/`.

1.  **`10-mail.conf`**: Define la ubicación y el formato de los buzones.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-mail.conf
    ```

    Asegúrate de que la siguientes líneas estén configuradas así:
	`mail_driver = mbox`
    `mail_home = /home/%{user|username}`
    `mail_path = %{home}/mail`
    `mail_inbox_path = /var/mail/%{user}`

2.  **`10-auth.conf`**: Configura los mecanismos de autenticación.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-auth.conf
    ```

    Modifica estas líneas:
    `disable_plaintext_auth = yes`
    `auth_mechanisms = plain login`

3.  **`10-master.conf`**: Configura el socket para la comunicación con Postfix.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-master.conf
    ```

    Busca el bloque `service auth` y modifícalo para que se vea así:

    ```
    service auth {
      unix_listener /var/spool/postfix/private/auth {
        mode = 0666
        user = postfix
        group = postfix
      }
    }
    ```

    Busca el bloque `service lmtp` y modifícalo así:

    ```
    service lmtp {
      unix_listener /var/spool/postfix/private/dovecot-lmtp {
        mode = 0600
        user = postfix
        group = postfix
      }
    }
    ```

4.  **`10-ssl.conf`**: Indica a Dovecot dónde encontrar los certificados SSL.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-ssl.conf
    ```

    Modifica estas líneas:
    `ssl = required`
    `ssl_cert = </etc/letsencrypt/live/mail.tu-dominio.com/fullchain.pem`
    `ssl_key = </etc/letsencrypt/live/mail.tu-dominio.com/privkey.pem`

-----

## **Paso 7: Análisis Antivirus con ClamAV** 🦠

**ClamAV** es un motor de antivirus de código abierto que puede ser integrado en tu servidor de correo para escanear adjuntos y correos entrantes en busca de malware, virus y otras amenazas.

1.  **Instalar ClamAV y su integración con Postfix:**

    ```bash
    sudo apt install clamav clamav-daemon clamav-milter clamsmtp
    ```

      * `clamav`: El motor de escaneo.
      * `clamav-daemon`: El demonio de ClamAV que se ejecuta en segundo plano.
      * `clamav-milter`: La interfaz para comunicarse con Postfix.
      * `clamsmtp`: Un filtro SMTP para integrar ClamAV con Postfix.

2.  **Configurar el usuario de `clamav-milter`:**
    El usuario `clamav` necesita permisos para conectarse al socket de `clamav-milter`.

    ```bash
    sudo nano /etc/clamav/clamav-milter.conf
    ```

    Asegúrate de que la línea `MilterSocketGroup` tenga el valor `clamav`:
    `MilterSocketGroup clamav`

3.  **Integrar el filtro en Postfix:**
    Edita el fichero de configuración principal de Postfix:

    ```bash
    sudo nano /etc/postfix/main.cf
    ```

    Añade las siguientes líneas al final del fichero:

    ```ini
# --- Integración con ClamAV ---
# Escaneado de correos entrantes para virus
content_filter = smtp:[127.0.0.1]:10024
# Permitir que Postfix pase el correo al filtro
receive_override_options = no_address_mappings
    ```

4.  **Configurar el servicio `clamsmtp`:**
    Edita el fichero de configuración del :filtro SMTP de ClamAV.

    ```bash
    sudo nano /etc/clamsmtp.conf
    ```

    Borra el contenido de clamsmtp.conf y copia y pega lo siguiente:

    ```ini
# The address to send scanned mail to.
# This option is required unless TransparentProxy is enabled
OutAddress: 10025

# The maximum number of connection allowed at once.
# Be sure that clamd can also handle this many connections
#MaxConnections: 64

# Amount of time (in seconds) to wait on network IO
#TimeOut: 180

# Address to listen on (defaults to all local addresses on port 10025)
Listen: 127.0.0.1:10024

# The address clamd is listening on
ClamAddress: /var/run/clamav/clamd.ctl

# A header to add to all scanned email
#Header: X-AV-Checked: ClamAV using ClamSMTP

# Directory for temporary files
TempDirectory: /var/spool/clamsmtp

# PidFile: location of PID file
PidFile: /var/run/clamsmtp/clamsmtpd.pid

# Whether or not to bounce email (default is to silently drop)
#Bounce: off

# Whether or not to keep virus files
#Quarantine: off

# Enable transparent proxy support
#TransparentProxy: off

# User to run as
User: clamsmtp

# Virus actions: There's an option to run a script every time a
# virus is found. Read the man page for clamsmtpd.conf for details.
    ```

5.  **Añadir el servicio `clamsmtp` a `master.cf` de Postfix:**
    Edita el fichero de configuración de servicios de Postfix.

    ```bash
    sudo nano /etc/postfix/master.cf
    ```

    Añade el siguiente bloque al final del fichero:

    ```
    # --- Interfaz para recibir correo ya escaneado por ClamAV ---
# Escucha en el puerto 10025, que coincide con OutAddress de clamsmtpd.conf
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
    ```

    Este bloque configura Postfix para que pase los correos al servicio `clamsmtp` y luego los reciba de vuelta para su entrega final.

6.  **Reiniciar los servicios:**
    *Es importante respetar el orden de arranque de los servicios o dara error de puerto.
    ```bash
    sudo systemctl restart clamav-daemon
    sudo systemctl restart clamsmtp
    sudo systemctl restart postfix
    ```

-----

## **Paso 8: Configuración de OpenDKIM (Firma de Correos)** ✍️

**OpenDKIM** firma digitalmente los correos salientes, probando que provienen de tu dominio y no han sido alterados.

1.  **Crear directorios y generar claves:**
    Usaremos la herramienta `opendkim-genkey` en lugar de un generador web.

    ```bash
    # Crear la estructura de directorios
    sudo mkdir -p /etc/opendkim/keys/tu-dominio.com

    # Generar la clave (privada y pública)
    sudo opendkim-genkey -b 2048 -d tu-dominio.com -D /etc/opendkim/keys/tu-dominio.com -s dkim2025

    # Cambiar el propietario al usuario de opendkim
    sudo chown -R opendkim:opendkim /etc/opendkim/keys

    # Asegurar que solo opendkim pueda leer la clave privada
    sudo chmod 600 /etc/opendkim/keys/tu-dominio.com/dkim2025.private
    ```

    Esto creará dos ficheros: `dkim2025.private` (la clave privada) y `dkim2025.txt` (el registro DNS que necesitas).

2.  **Mostrar el registro DNS DKIM que debes crear:**
    Ejecuta este comando para ver el contenido que necesitas añadir a tu DNS:

    ```bash
    sudo cat /etc/opendkim/keys/tu-dominio.com/dkim2025.txt
    ```

    Verás algo como:
    `dkim2025._domainkey IN TXT ( "v=DKIM1; k=rsa; p=MIIBIjANBgkqh...[clave muy larga]...AQAB" )`

    **Acción:** Ve a tu panel de DNS y crea un **registro TXT** con:

      * **Host/Nombre:** `dkim2025._domainkey`
      * **Valor:** El contenido entre las comillas, empezando por `v=DKIM1...`

3.  **Configurar OpenDKIM:**
    Edita el fichero `/etc/opendkim.conf`. Reemplaza su contenido con lo siguiente:

    ```ini
    # --- Configuración General ---
    Syslog               yes
    UMask                002

    # --- Conexión ---
    Socket               inet:8891@localhost

    # --- Modo de Operación ---
    Mode                 sv
    Canonicalization     relaxed/simple

    # --- Ficheros de Configuración ---
    KeyTable             refile:/etc/opendkim/KeyTable
    SigningTable         refile:/etc/opendkim/SigningTable
    ExternalIgnoreList   refile:/etc/opendkim/TrustedHosts
    InternalHosts        refile:/etc/opendkim/TrustedHosts
    ```

4.  **Crear los ficheros `KeyTable` y `SigningTable`:**

      * **`KeyTable`**: Mapea un nombre de clave a la clave privada.

        ```bash
        sudo nano /etc/opendkim/KeyTable
        ```

        Añade esta línea:
        `dkim2025._domainkey.tu-dominio.com tu-dominio.com:dkim2025:/etc/opendkim/keys/tu-dominio.com/dkim2025.private`

      * **`SigningTable`**: Indica qué clave usar para qué dirección de correo.

        ```bash
        sudo nano /etc/opendkim/SigningTable
        ```

        Añade esta línea:
        `*@tu-dominio.com dkim2025._domainkey.tu-dominio.com`

5.  **Crear el fichero `TrustedHosts`**:

    ```bash
    sudo nano /etc/opendkim/TrustedHosts
    ```

    Añade estas líneas para que los correos locales se firmen:

    ```
    127.0.0.1
    localhost
    *.tu-dominio.com
    ```

-----

## **Paso 9: Pasos Finales y Verificación** ✅

1.  **Reiniciar todos los servicios:**
    El orden es importante.

    ```bash
    sudo systemctl restart opendkim
    sudo systemctl restart postfix
    sudo systemctl restart dovecot
    sudo systemctl restart fail2ban
    ```

2.  **Habilitar los servicios para que inicien con el sistema:**

    ```bash
    sudo systemctl enable opendkim postfix dovecot fail2ban
    ```

3.  **Añadir un usuario (si no tienes uno):**
    Cada cuenta de correo corresponde a un usuario del sistema.

    ```bash
    sudo adduser usuario1
    ```

4.  **Verificar la configuración:**
    La mejor forma de probar tu servidor es enviando un correo a un servicio de análisis como **[Mail-Tester](https://www.mail-tester.com/)**.

      * Ve a la web, copia la dirección de correo que te proporcionan.
      * Desde un cliente de correo (como Thunderbird) configurado para usar tu nuevo servidor, envía un correo a esa dirección.
      * Vuelve a la web y comprueba tu puntuación. El objetivo es **10/10**. El informe te dirá si tus registros SPF, DKIM, PTR y DMARC son correctos.

5.  **Cambiar el registro dns DMARC a otro más restrictivo:**
    La diferencia principal entre `p=quarantine` y `p=reject` en tu política DMARC es la severidad de la acción que le pides a los servidores de correo que tomen con los emails que fallen la autenticación.

      * **`p=quarantine` (Cuarentena):** 🗑️

          * Esta política le indica al servidor de correo receptor que trate los correos sospechosos con precaución. En lugar de rechazarlos, los emails que no superan la verificación DMARC se "ponen en cuarentena", lo que en la práctica significa que son movidos a la carpeta de correo no deseado o spam del destinatario. Es un paso intermedio excelente.

      * **`p=reject` (Rechazar):** 🚫

          * Esta es la política más estricta. Le da una orden directa al servidor receptor para que rechace por completo cualquier email que no supere la verificación DMARC. El correo ni siquiera llega a la bandeja de entrada o a la carpeta de spam. Solo debes implementarla cuando estés totalmente seguro de que todas las fuentes que envían correos en tu nombre están correctamente autenticadas con SPF y DKIM.

    ¡Felicidades\! Si has llegado hasta aquí y tu puntuación en Mail-Tester es buena, tienes un servidor de correo funcional y correctamente configurado.
