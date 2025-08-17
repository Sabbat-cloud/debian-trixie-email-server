# Complete Guide to Setting Up a Mail Server on Debian 13 "Trixie" 📧

A mail server allows you to send and receive emails from your own domain (e.g., `yourname@your-domain.com`). It's ideal for businesses, personal projects, or for learning about mail infrastructure. This guide will help you set up a secure and functional server on Debian 13.

Installing a functional and secure mail server is a process that requires attention to detail. This guide will take you step-by-step through configuring a modern and robust mail server on **Debian 13**. We will cover everything from the prerequisites and critical DNS setup to the installation and configuration of essential software.

### ⚙️ **Main Components**

  * **Operating System:** Debian 13 "Trixie"
  * **MTA (Mail Transfer Agent):** Postfix
  * **IMAP/POP3 Server:** Dovecot
  * **Email Signing (Authentication):** OpenDKIM
  * **Attack Protection:** Fail2ban
  * **Antivirus Scanning:** ClamAV

### **Example Data Used**

Throughout this guide, replace the following values with your own:

  * **Domain:** `your-domain.com`
  * **Server Hostname (FQDN):** `mail.your-domain.com`
  * **Static Public IP:** `123.45.67.89`
  * **DKIM Selector:** `dkim2025` (you can choose another one, like `mail` or `key1`)

-----

## **Step 1: Essential Preparations**

Before installing any packages, it is crucial to have a solid foundation.

### **1.1. Server and Domain Requirements**

  * **A server:** A VPS or dedicated server with a **static public IP address**.
  * **A domain:** A registered domain name (e.g., `your-domain.com`).

### **1.2. Hostname Configuration (FQDN)**

Your server's name must be an **FQDN** (Fully Qualified Domain Name), such as `mail.your-domain.com`.

1.  **Set the hostname:**
    ```bash
    sudo hostnamectl set-hostname mail.your-domain.com
    ```
2.  **Verify the `/etc/hosts` file:**
    Ensure that this file associates your public IP with your FQDN. It should have a line similar to this:
    ```
    123.45.67.89 mail.your-domain.com mail
    ```

### **1.3. System Update**

Make sure your system is fully updated.

```bash
sudo apt update && sudo apt upgrade -y
```

-----

## **Step 2: Critical DNS Configuration** 🌐

A correct DNS configuration is **the key to preventing your emails from being marked as spam**. Access your domain provider's control panel to configure the following records.

### **PTR Record (Reverse DNS) - Mandatory\!**

This record associates your IP with your server name (`123.45.67.89` -\> `mail.your-domain.com`). **You cannot create this yourself in your domain panel**.

  * **Action:** You must ask your hosting provider (where you have the server) to set it up.
  * **Example Request:** "Please set up the PTR record for the IP `123.45.67.89` to point to `mail.your-domain.com`."
      * *Note: Providers like IONOS, Vultr, or DigitalOcean often allow you to configure this directly from their server control panel.*

### **Records in Your Domain Panel**

| TYPE | HOSTNAME | VALUE / POINTS TO | FUNCTION |
| :--- | :--- | :--- | :--- |
| **A** | `mail` | `123.45.67.89` | Associates the mail server name with its IP. |
| **MX** | `@` | `mail.your-domain.com` | Indicates that all mail for `your-domain.com` is handled by your server. |
| **SPF**| `@` | `v=spf1 mx -all` | Authorizes the servers listed in your MX records (i.e., your server) to send emails. |
| **DMARC**| `_dmarc`| `v=DMARC1; p=none; rua=mailto:admin@your-domain.com` | Defines the authentication policy and where to send reports. |
| **DKIM** | `dkim2025._domainkey` | (Value generated later) | Contains the public key to verify the signature of your emails. We will leave this pending and complete it in **Step 6**. |

**Propagation time:** DNS records can take up to 24-48 hours to propagate. The changes are not immediate.

-----

## **Step 3: Firewall Configuration** 🔥

You must open the necessary ports for email to enter and exit. Use `ufw` (Uncomplicated Firewall) or your provider's firewall.

1.  **Install UFW (if not present):**

    ```bash
    sudo apt install ufw
    ```

2.  **Open the necessary ports:**

    ```bash
    # SSH access (use your custom port if you have changed it)
    sudo ufw allow 22/tcp

    # SMTP (mail reception and server-to-server sending)
    sudo ufw allow 25/tcp

    # Submission (sending mail from clients like Outlook/Thunderbird)
    sudo ufw allow 587/tcp

    # IMAPS (secure mail reading)
    sudo ufw allow 993/tcp

    # Enable the firewall
    sudo ufw enable
    ```

> **Important\!** Many hosting providers block **outbound port 25** by default to prevent spam. Contact their support and request that they unblock it for your server.

-----

## **Step 4: Attack Protection with Fail2ban** 🛡️

**Fail2ban** is an essential tool that scans log files for failed login attempts or brute-force attacks. When it detects a series of failed attempts from the same IP, it temporarily blocks it in the firewall.

1.  **Install Fail2ban:**

    ```bash
    sudo apt install fail2ban
    ```

2.  **Create a local configuration file:**
    Do not edit the `jail.conf` file directly. It is better to create a `jail.local` file for your custom settings.

    ```bash
    sudo nano /etc/fail2ban/jail.local
    ```

3.  **Add configurations for Postfix and Dovecot:**
    Paste the following content into the file. This will enable protection for login attempts on your mail services and connection attempts to the SMTP server.

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

      * `bantime`: Duration of the block (in this case, 1 hour).
      * `findtime`: Time window to count failed attempts (in this case, 10 minutes).
      * `maxretry`: Number of failed attempts before blocking the IP (in this case, 5).

4.  **Restart the Fail2ban service:**

    ```bash
    sudo systemctl restart fail2ban
    ```

-----

## **Step 5: SSL/TLS Certificates with Let's Encrypt** 🔐

To encrypt communications and ensure your server is trusted, we will use free certificates from Let's Encrypt.

1.  **Install Certbot:**

    ```bash
    sudo apt install certbot
    ```

2.  **Obtain the certificate:**
    We will use the `standalone` method, which starts a small temporary web server for validation. Make sure ports 80 and 443 are not in use by another service.

    ```bash
    sudo certbot certonly --standalone -d mail.your-domain.com
    ```

    Follow the on-screen instructions (enter your email and accept the terms).

3.  **Verify the files:**
    Your certificates will be saved in `/etc/letsencrypt/live/mail.your-domain.com/`. The two files we will use are:

      * `fullchain.pem` (your certificate + the trust chain)
      * `privkey.pem` (your private key)

4.  **Configure automatic renewal:**
    Certbot creates a `systemd` timer that renews the certificates automatically. For Postfix and Dovecot to use the new certificate after renewal, we must create a "hook".

    Create the following script:

    ```bash
    sudo nano /etc/letsencrypt/renewal-hooks/deploy/restart-mail.sh
    ```

    Add this content:

    ```bash
    #!/bin/sh
    # Restart mail services to load the new certificate

    systemctl restart postfix
    systemctl restart dovecot
    ```

    Make it executable:

    ```bash
    sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-mail.sh
    ```

-----

## **Step 6: Installation and Configuration of Mail Software** 📦

Now we will install and configure the heart of our server.

### **6.1. Package Installation**

```bash
sudo apt update
sudo apt install postfix dovecot-core dovecot-imapd dovecot-lmtpd opendkim opendkim-tools dig
```

During the Postfix installation:

  * On the first screen, select **Internet Site**.
  * On the second, enter your domain name: `your-domain.com`.

### **6.2. Postfix Configuration** 📬

**Postfix** is responsible for sending and receiving emails.

1.  **Back up the original files:**
    ```bash
    sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
    sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.bak
    ```
2.  **Edit `/etc/postfix/main.cf`:**
    Replace its content with this configuration, adapting it to your data.
    ```ini
    # --- Server Identity ---
    myhostname = mail.your-domain.com
    mydomain = your-domain.com
    myorigin = $mydomain

    # --- Destinations and Networks ---
    mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
    mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
    relayhost =

    # --- Mailbox Format ---
    home_mailbox = Maildir/

    # --- SMTP Banner ---
    smtpd_banner = $myhostname ESMTP

    # --- TLS Configuration (Let's Encrypt) ---
    smtpd_tls_cert_file = /etc/letsencrypt/live/mail.your-domain.com/fullchain.pem
    smtpd_tls_key_file = /etc/letsencrypt/live/mail.your-domain.com/privkey.pem
    smtpd_tls_security_level = may
    smtp_tls_security_level = may

    # --- SASL Authentication (via Dovecot) ---
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable = yes
    smtpd_sasl_security_options = noanonymous
    smtpd_sasl_local_domain = $myhostname

    # --- Relay Restrictions ---
    smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination

    # --- OpenDKIM Integration ---
    milter_default_action = accept
    milter_protocol = 4
    smtpd_milters = inet:localhost:8891
    non_smtpd_milters = $smtpd_milters

    # --- Local Delivery to Dovecot via LMTP ---
    mailbox_transport = lmtp:unix:private/dovecot-lmtp

    # --- Aliases ---
    alias_maps = hash:/etc/aliases
    alias_database = hash:/etc/aliases
    ```
3.  **Edit `/etc/postfix/master.cf`:**
    Ensure the `submission` (port 587) and `smtps` (port 465) sections are uncommented and configured to use SASL authentication. Find these lines at the beginning of the file and modify or add them:
    ```
    submission inet n       -       y       -       -       smtpd
      -o syslog_name=postfix/submission
      -o smtpd_tls_security_level=encrypt
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_relay_restrictions=permit_sasl_authenticated,reject

    smtps     inet  n       -       y       -       -       smtpd
      -o syslog_name=postfix/smtps
      -o smtpd_tls_wrappermode=yes
      -o smtpd_sasl_auth_enable=yes
      -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
    ```

### **6.3. Dovecot Configuration** 📥

**Dovecot** allows users to access their mailboxes via IMAP.

We will make changes to several configuration files within `/etc/dovecot/conf.d/`.

1.  **`10-mail.conf`**: Defines the location and format of the mailboxes.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-mail.conf
    ```

    Ensure the following lines are configured as follows:
    `mail_driver = mbox`
    `mail_home = /home/%{user|username}`
    `mail_path = %{home}/mail`
    `mail_inbox_path = /var/mail/%{user}`

2.  **`10-auth.conf`**: Configures authentication mechanisms.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-auth.conf
    ```

    Modify these lines:
    `disable_plaintext_auth = yes`
    `auth_mechanisms = plain login`

3.  **`10-master.conf`**: Configures the socket for communication with Postfix.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-master.conf
    ```

    Find the `service auth` block and modify it to look like this:

    ```
    service auth {
      unix_listener /var/spool/postfix/private/auth {
        mode = 0666
        user = postfix
        group = postfix
      }
    }
    ```

    Find the `service lmtp` block and modify it as follows:

    ```
    service lmtp {
      unix_listener /var/spool/postfix/private/dovecot-lmtp {
        mode = 0600
        user = postfix
        group = postfix
      }
    }
    ```

4.  **`10-ssl.conf`**: Tells Dovecot where to find the SSL certificates.

    ```bash
    sudo nano /etc/dovecot/conf.d/10-ssl.conf
    ```

    Modify these lines:
    `ssl = required`
    `ssl_cert = </etc/letsencrypt/live/mail.your-domain.com/fullchain.pem`
    `ssl_key = </etc/letsencrypt/live/mail.your-domain.com/privkey.pem`

-----

## **Step 7: Antivirus Scanning with ClamAV** 🦠

**ClamAV** is an open-source antivirus engine that can be integrated into your mail server to scan attachments and incoming emails for malware, viruses, and other threats.

1.  **Install ClamAV and its integration with Postfix:**

    ```bash
    sudo apt install clamav clamav-daemon clamav-milter clamsmtp
    ```

      * `clamav`: The scanning engine.
      * `clamav-daemon`: The ClamAV daemon that runs in the background.
      * `clamav-milter`: The interface to communicate with Postfix.
      * `clamsmtp`: An SMTP filter to integrate ClamAV with Postfix.

2.  **Configure the `clamav-milter` user:**
    The `clamav` user needs permissions to connect to the `clamav-milter` socket.

    ```bash
    sudo nano /etc/clamav/clamav-milter.conf
    ```

    Ensure the `MilterSocketGroup` line has the value `clamav`:
    `MilterSocketGroup clamav`

3.  **Integrate the filter into Postfix:**
    Edit the main Postfix configuration file:

    ```bash
    sudo nano /etc/postfix/main.cf
    ```

    Add the following lines at the end of the file:

    ```ini
    # --- ClamAV Integration ---
    # Scan incoming emails for viruses
    content_filter = smtp:[127.0.0.1]:10024
    # Allow Postfix to pass the email to the filter
    receive_override_options = no_address_mappings
    ```

4.  **Configure the `clamsmtp` service:**
    Edit the configuration file for the ClamAV SMTP filter.

    ```bash
    sudo nano /etc/clamsmtp.conf
    ```

    Delete the contents of clamsmtp.conf and copy and paste the following:

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

5.  **Add the `clamsmtp` service to Postfix's `master.cf`:**
    Edit the Postfix services configuration file.

    ```bash
    sudo nano /etc/postfix/master.cf
    ```

    Add the following block at the end of the file:

    ```
    # --- Interface to receive mail already scanned by ClamAV ---
    # Listens on port 10025, which matches OutAddress in clamsmtpd.conf
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

    This block configures Postfix to pass emails to the `clamsmtp` service and then receive them back for final delivery.

6.  **Restart the services:**
    *It is important to respect the service startup order, or a port error will occur.*

    ```bash
    sudo systemctl restart clamav-daemon
    sudo systemctl restart clamsmtp
    sudo systemctl restart postfix
    ```

-----

## **Step 8: OpenDKIM Configuration (Email Signing)** ✍️

**OpenDKIM** digitally signs outgoing emails, proving that they come from your domain and have not been altered.

1.  **Create directories and generate keys:**
    We will use the `opendkim-genkey` tool instead of a web generator.

    ```bash
    # Create the directory structure
    sudo mkdir -p /etc/opendkim/keys/your-domain.com

    # Generate the key (private and public)
    sudo opendkim-genkey -b 2048 -d your-domain.com -D /etc/opendkim/keys/your-domain.com -s dkim2025

    # Change the owner to the opendkim user
    sudo chown -R opendkim:opendkim /etc/opendkim/keys

    # Ensure only opendkim can read the private key
    sudo chmod 600 /etc/opendkim/keys/your-domain.com/dkim2025.private
    ```

    This will create two files: `dkim2025.private` (the private key) and `dkim2025.txt` (the DNS record you need).

2.  **Display the DKIM DNS record you need to create:**
    Run this command to see the content you need to add to your DNS:

    ```bash
    sudo cat /etc/opendkim/keys/your-domain.com/dkim2025.txt
    ```

    You will see something like:
    `dkim2025._domainkey IN TXT ( "v=DKIM1; k=rsa; p=MIIBIjANBgkqh...[very long key]...AQAB" )`

    **Action:** Go to your DNS panel and create a **TXT record** with:

      * **Host/Name:** `dkim2025._domainkey`
      * **Value:** The content between the quotes, starting with `v=DKIM1...`

3.  **Configure OpenDKIM:**
    Edit the `/etc/opendkim.conf` file. Replace its contents with the following:

    ```ini
    # --- General Configuration ---
    Syslog                  yes
    UMask                   002

    # --- Connection ---
    Socket                  inet:8891@localhost

    # --- Operation Mode ---
    Mode                    sv
    Canonicalization        relaxed/simple

    # --- Configuration Files ---
    KeyTable                refile:/etc/opendkim/KeyTable
    SigningTable            refile:/etc/opendkim/SigningTable
    ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
    InternalHosts           refile:/etc/opendkim/TrustedHosts
    ```

4.  **Create the `KeyTable` and `SigningTable` files:**

      * **`KeyTable`**: Maps a key name to the private key.
        ```bash
        sudo nano /etc/opendkim/KeyTable
        ```
        Add this line:
        `dkim2025._domainkey.your-domain.com your-domain.com:dkim2025:/etc/opendkim/keys/your-domain.com/dkim2025.private`
      * **`SigningTable`**: Specifies which key to use for which email address.
        ```bash
        sudo nano /etc/opendkim/SigningTable
        ```
        Add this line:
        `*@your-domain.com dkim2025._domainkey.your-domain.com`

5.  **Create the `TrustedHosts` file:**

    ```bash
    sudo nano /etc/opendkim/TrustedHosts
    ```

    Add these lines so that local emails are signed:

    ```
    127.0.0.1
    localhost
    *.your-domain.com
    ```

-----

## **Step 9: Final Steps and Verification** ✅

1.  **Restart all services:**
    The order is important.

    ```bash
    sudo systemctl restart opendkim
    sudo systemctl restart postfix
    sudo systemctl restart dovecot
    sudo systemctl restart fail2ban
    ```

2.  **Enable services to start on boot:**

    ```bash
    sudo systemctl enable opendkim postfix dovecot fail2ban
    ```

3.  **Add a user (if you don't have one):**
    Each email account corresponds to a system user.

    ```bash
    sudo adduser user1
    ```

4.  **Verify the configuration:**
    The best way to test your server is by sending an email to an analysis service like **[Mail-Tester](https://www.mail-tester.com/)**.

      * Go to the website, copy the email address they provide.
      * From a mail client (like Thunderbird) configured to use your new server, send an email to that address.
      * Return to the website and check your score. The goal is **10/10**. The report will tell you if your SPF, DKIM, PTR, and DMARC records are correct.

5.  **Change the DMARC DNS record to a more restrictive one:**
    The main difference between `p=quarantine` and `p=reject` in your DMARC policy is the severity of the action you ask mail servers to take with emails that fail authentication.

      * **`p=quarantine`:** 🗑️
          * This policy tells the receiving mail server to treat suspicious emails with caution. Instead of rejecting them, emails that fail DMARC verification are "quarantined," which in practice means they are moved to the recipient's junk or spam folder. It is an excellent intermediate step.
      * **`p=reject`:** 🚫
          * This is the strictest policy. It gives a direct order to the receiving server to completely reject any email that fails DMARC verification. The email does not even reach the inbox or the spam folder. You should only implement it when you are completely sure that all sources sending emails on your behalf are correctly authenticated with SPF and DKIM.

Congratulations\! If you have reached this point and your score on Mail-Tester is good, you have a functional and correctly configured mail server.
