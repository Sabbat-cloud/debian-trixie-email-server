# Script de Automatización de Servidor de Correo para Debian 13
[English](README.md) | [**Español**]

Este script automatiza la configuración de un servidor de correo completo y seguro en una instalación limpia de **Debian 13 "Trixie"**. Está diseñado para seguir las mejores prácticas, configurando todos los componentes necesarios para enviar y recibir correo desde tu propio dominio.

## ✨ Características

- **Automatización Completa:** Configura el sistema, firewall, certificados SSL y todo el software de correo con una sola ejecución.
- **Interactivo:** Pide la información necesaria (dominio, IP, usuario) al inicio.
- **Seguro por Defecto:** Implementa Fail2ban para protección contra fuerza bruta, OpenDKIM para autenticación de correos y ClamAV para análisis de virus.
- **Certificados SSL Gratuitos:** Utiliza Certbot para obtener e instalar certificados de Let's Encrypt, incluyendo un hook para la renovación automática.
- **Creación de Usuario:** Configura automáticamente la primera cuenta de correo con una contraseña segura y aleatoria.
- **Copias de Seguridad:** Crea copias de seguridad de todos los ficheros de configuración antes de modificarlos.

## ⚙️ Componentes Configurados

El script instalará y configurará la siguiente pila de software:

- **MTA:** Postfix
- **Servidor IMAP:** Dovecot
- **Firma de Correo:** OpenDKIM
- **Protección de Seguridad:** Fail2ban
- **Antivirus:** ClamAV
- **Certificados SSL:** Certbot (Let's Encrypt)

---

## 🚀 Requisitos Previos

- **Sistema Operativo:** Una instalación limpia de Debian 13 "Trixie".
- **Servidor:** Un VPS o servidor dedicado con una **dirección IP pública estática**.
- **Dominio:** Un nombre de dominio registrado.
- **Acceso:** Debes ejecutar el script como usuario `root` o con `sudo`.

---

## 📋 Uso

1.  **Descargar el script:**
    ```bash
    wget https://ruta/al/fichero/setup-mail-server.sh
    ```

2.  **Darle permisos de ejecución:**
    ```bash
    chmod +x setup-mail-server.sh
    ```

3.  **Ejecutar el script:**
    ```bash
    sudo ./setup-mail-server.sh
    ```

4.  **Seguir las instrucciones:**
    El script te pedirá tu dominio, la IP pública del servidor y un nombre de usuario para la primera cuenta de correo. El resto del proceso es automático.

---

## ⚠️ Acciones Manuales Requeridas (Post-Instalación)

El script no puede configurar tu DNS por ti. Una vez que el script finalice, **debes realizar las siguientes acciones** en el panel de control de tu proveedor de dominio y de hosting:

1.  **Registro PTR (DNS Inverso):** Solicita a tu proveedor de hosting que configure el registro PTR de tu IP para que apunte a tu hostname (ej. `mail.tudominio.com`).
2.  **Registro DKIM:** El script generará una clave DKIM y te mostrará el registro TXT que debes crear en tu DNS.
3.  **Otros Registros DNS:** Asegúrate de que tienes los registros A, MX, SPF y DMARC configurados correctamente.

El script te proporcionará un resumen claro de estas acciones al finalizar.

##  Puedes configurar manualmente todo el proceso siguiendo esta guia
[Instalacion manual](manualinstall-es.md) 

> **Descargo de responsabilidad:** Revisa el script antes de ejecutarlo en un entorno de producción. Úsalo bajo tu propio riesgo.
