[Español](README.es.md) | [**English**]

# Debian 13 Mail Server Automation Script

This script automates the setup of a complete and secure mail server on a clean installation of **Debian 13 "Trixie"**. It is designed to follow best practices, configuring all the necessary components to send and receive email from your own domain.

## ✨ Features

- **Full Automation:** Configures the system, firewall, SSL certificates, and all mail software with a single run.
- **Interactive:** Prompts for the necessary information (domain, IP, user) at the beginning.
- **Secure by Default:** Implements Fail2ban for brute-force protection, OpenDKIM for email authentication, and ClamAV for virus scanning.
- **Free SSL Certificates:** Uses Certbot to obtain and install certificates from Let's Encrypt, including a hook for automatic renewal.
- **User Creation:** Automatically sets up the first email account with a secure, random password.
- **Backups:** Creates backup copies of all configuration files before modifying them.

## ⚙️ Components Configured

The script will install and configure the following software stack:

- **MTA:** Postfix
- **IMAP Server:** Dovecot
- **Email Signing:** OpenDKIM
- **Security Protection:** Fail2ban
- **Antivirus:** ClamAV
- **SSL Certificates:** Certbot (Let's Encrypt)

---

## 🚀 Prerequisites

- **Operating System:** A clean installation of Debian 13 "Trixie".
- **Server:** A VPS or dedicated server with a **static public IP address**.
- **Domain:** A registered domain name.
- **Access:** You must run the script as the `root` user or with `sudo`.

---

## 📋 Usage

1.  **Download the script:**
    ```bash
    wget https://path/to/the/file/setup-mail-server.sh
    ```

2.  **Make it executable:**
    ```bash
    chmod +x setup-mail-server.sh
    ```

3.  **Run the script:**
    ```bash
    sudo ./setup-mail-server.sh
    ```

4.  **Follow the prompts:**
    The script will ask for your domain, the server's public IP, and a username for the first email account. The rest of the process is automatic.

---

## ⚠️ Required Manual Actions (Post-Installation)

The script cannot configure your DNS for you. After the script finishes, **you must perform the following actions** in your domain provider and hosting provider control panels:

1.  **PTR Record (Reverse DNS):** Ask your hosting provider to set the PTR record for your IP to point to your hostname (e.g., `mail.yourdomain.com`).
2.  **DKIM Record:** The script will generate a DKIM key and show you the TXT record that you need to create in your DNS.
3.  **Other DNS Records:** Ensure you have correctly configured your A, MX, SPF, and DMARC records.

The script will provide you with a clear summary of these actions upon completion.

##  You can do the entire process manually using this guide: 
[Manual Guide](manualinstall.md)

> **Disclaimer:** Please review the script before running it in a production environment. Use it at your own risk.
