# LaraShip - Laravel VPS Auto-Deploy Scripts

A collection of shell scripts that automate the deployment of production-ready **LEMP Stack** (Linux, Nginx, MySQL, PHP) applications on Ubuntu servers, tailored specifically for **Laravel**.

---

## Scripts

| Script | Purpose |
|---|---|
| `laravel_deploy.sh` | Fresh Laravel install — creates a new project from scratch |
| `laravel_deploy_github.sh` | GitHub deploy — clones your existing repo and sets everything up |

---

## laravel_deploy.sh — Fresh Install

### Features
- **Automated Updates:** Updates system packages and adds PHP PPA.
- **Custom PHP:** Install any specific PHP version (e.g., 8.1, 8.2, 8.3).
- **Database Management:** Automatically creates a MySQL database and a dedicated user with a secure password.
- **Composer:** Installs the latest version of Composer globally.
- **Laravel Installation:** Creates a fresh Laravel project via Composer.
- **Automatic .env Config:** Links the new database credentials to the Laravel `.env` file.
- **Security:** Sets correct folder permissions and installs **SSL (Let's Encrypt)** via Certbot.

### Installation

1. **Connect to your server via SSH:**
    ```bash
    ssh root@your_server_ip
    ```

2. **Clone the repository:**
    ```bash
    git clone https://github.com/adnnco/LaraShip.git && cd LaraShip
    ```

3. **Make the script executable:**
    ```bash
    chmod +x laravel_deploy.sh
    ```

4. **Run the script:**
    ```bash
    sudo ./laravel_deploy.sh
    ```

    The script will prompt you for:
    - Project name
    - Domain name
    - SSL email
    - PHP version

---

## laravel_deploy_github.sh — GitHub Deploy

Deploys an **existing Laravel repository** from GitHub. Supports both interactive and fully non-interactive (CI/CD) modes.

### Features
- **SSH Deploy Key:** Automatically generates an ed25519 SSH key and guides you through adding it to GitHub — works with private and public repositories.
- **GitHub Clone:** Clones your repo directly from GitHub via SSH with a specified branch.
- **Re-deploy Support:** If the project directory already exists, runs `git pull` instead of re-cloning.
- **Branch Selection:** Deploy any branch or tag (defaults to `main`).
- **Composer:** Installs dependencies with `--no-dev --optimize-autoloader` for production.
- **Artisan Setup:** Automatically runs `key:generate`, `migrate`, and caches config/routes/views (as `www-data` to avoid permission issues).
- **Storage Directories:** Creates all required Laravel `storage/framework/*` subdirectories before setting permissions, preventing cache path errors.
- **Automatic .env Config:** Copies `.env.example` and injects database credentials.
- **Database Management:** Creates a MySQL database and dedicated user with a secure random password.
- **Security:** Sets correct folder permissions and installs **SSL (Let's Encrypt)** via Certbot.
- **Confirmation Prompt:** Shows a config summary before making any changes.

### Installation

1. **Connect to your server via SSH:**
    ```bash
    ssh root@your_server_ip
    ```

2. **Clone the repository:**
    ```bash
    git clone https://github.com/adnnco/LaraShip.git && cd LaraShip
    ```

3. **Make the script executable:**
    ```bash
    chmod +x laravel_deploy_github.sh
    ```

4. **Run the script:**

    **Option A — Pass all parameters (non-interactive / CI-CD friendly):**
    ```bash
    sudo ./laravel_deploy_github.sh \
      --repo    git@github.com:your-user/your-repo.git \
      --branch  main \
      --project my-app \
      --domain  example.com \
      --email   admin@example.com \
      --php     8.3
    ```

    **Option B — Interactive (prompts for anything not passed):**
    ```bash
    sudo ./laravel_deploy_github.sh --repo git@github.com:your-user/your-repo.git
    ```

5. **Add the deploy key to GitHub when prompted:**

    The script will pause and print an SSH public key. Copy it, then go to:
    > **GitHub repo → Settings → Deploy keys → Add deploy key**

    Paste the key, give it a title (e.g., `VPS Deploy`), and click **Add key**.
    Press `ENTER` in the terminal to continue.

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--repo` | Yes | — | GitHub repository SSH URL (e.g., `git@github.com:user/repo.git`) |
| `--branch` | No | `main` | Branch or tag to deploy |
| `--project` | No | prompted | Project/folder name under `/var/www/` |
| `--domain` | No | prompted | Domain name for Nginx and SSL |
| `--email` | No | prompted | Email address for Let's Encrypt |
| `--php` | No | prompted | PHP version to install (e.g., `8.3`) |

---

## Prerequisites

1. A fresh **Ubuntu 20.04 or 22.04+** VPS (Droplet, AWS EC2, etc.).
2. A **Domain Name** pointed to your server's IP address (A Record).
3. Root or sudo access.

---

## Post-Installation

Once either script finishes, it will print your **Database Credentials**. Save them securely!

- **Project Directory:** `/var/www/your-project-name`
- **Nginx Config:** `/etc/nginx/sites-available/your-project-name`
- **Log Files:** `/var/www/your-project-name/storage/logs`

---

## Important Notes

- **SSL:** The Certbot step will fail if your domain's DNS has not propagated yet.
- **PHP Extensions:** The scripts install the most common Laravel extensions. If you need extras (e.g., `php-gd`, `php-imagick`), add them manually via `apt install`.
- **SSH Key:** The generated deploy key is saved at `/root/.ssh/github_deploy`. If you re-run the script the same key is reused — no need to update GitHub.
- **Private Repos:** SSH deploy keys work for both private and public repositories. Read-only access is sufficient for deployment.

---

*Created with ❤️ for Laravel Developers.*
