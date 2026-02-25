# LaraShip - Laravel VPS Auto-Deploy Script
This script automates the installation of a production-ready **LEMP Stack** (Linux, Nginx, MySQL, PHP) on an Ubuntu server, specifically tailored for **Laravel** applications.

## 🚀 Features
* **Automated Updates:** Updates system packages and adds PHP PPA.
* **Custom PHP:** Install any specific PHP version (e.g., 8.1, 8.2, 8.3).
* **Database Management:** Automatically creates a MySQL database and a dedicated user with a secure password.
* **Composer:** Installs the latest version of Composer globally.
* **Laravel Installation:** Clones a fresh Laravel skeleton.
* **Automatic .env Config:** Links the new database credentials to the Laravel `.env` file.
* **Security:** Sets correct folder permissions and installs **SSL (Let's Encrypt)** via Certbot.

## 📋 Prerequisites
1.  A fresh **Ubuntu 20.04 or 22.04+** VPS (Droplet, AWS EC2, etc.).
2.  A **Domain Name** pointed to your server's IP address (A Record).
3.  Root or sudo access.

## 🛠 Installation

1.  **Connect to your server via SSH:**
    ```bash
    ssh root@your_server_ip
    ```

2.  **Download the script:**
    ```bash
    wget https://raw.githubusercontent.com/adnnco/LaraShip/main/laravel_deploy.sh
    ```
    *(Paste the content of the script and save with Ctrl+O, Enter, Ctrl+X)*

3.  **Make the script executable:**
    ```bash
    chmod +x laravel_deploy.sh
    ```

4.  **Run the script:**
    ```bash
    sudo ./laravel_deploy.sh
    ```

## 📝 Post-Installation
Once the script finishes, it will print your **Database Credentials**. Save them securely!

* **Project Directory:** `/var/www/your-project-name`
* **Nginx Config:** `/etc/nginx/sites-available/your-project-name`
* **Log Files:** `/var/www/your-project-name/storage/logs`

## ⚠️ Important Notes
* **SSL:** The Certbot step will fail if your domain's DNS has not propagated yet.
* **PHP Extensions:** The script installs the most common Laravel extensions. If you need specific ones (like `php-gd` or `php-imagick`), you can add them manually via `apt install`.

---
*Created with ❤️ for Laravel Developers.*
