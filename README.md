# 42 Cursus - Born2BeRoot

Création d'un serveur virtuel sur VirtualBox.

Le système sera sous GNU/Linux Debian 64Bits en version stable.

## Création de la VM en CLI sous VirtualBox

Dans le cadre, de ce projet nous utiliserons VirtualBox. Pour cela je vais faire la création et le paramétrage de la machine via l'outil en ligne [VBoxManage](https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/vboxmanage.html) de commande.

Un script permettant de faire les commandes suivantes est dispo à `./scripts/create-vm.sh`.

**Création de la VM**

```bash
VBoxManage createvm --name "Born2BeRootDebian" --ostype "Debian_64" --register --basefolder <path-where-store-vms>
```

**Paramétrage de la RAM et VRAM**

```bash
VBoxManage modifyvm "Born2BeRootDebian" --ioapic on # Increase performance
VBoxManage modifyvm "Born2BeRootDebian" --memory 1024 --vram 128
```

**Réglage de la carte réseau**

Je laisse la config par défaut en `NAT` cela permet de faire notre routing de ports en cas de service en doublon sur la machine.

**Création d'un controlleur SATA**

```bash
VBoxManage storagectl "Born2BeRootDebian" --name "SATA Controller" --add sata --controller IntelAhci
```

**Création du disque dur et attachement au SATA**

```bash
VBoxManage createmedium disk --filename <path-to-disk>/Born2BeRootDebian.vdi --format VDI --size 35000 --variant Standard
VBoxManage storageattach "Born2BeRootDebian" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium <path-to-disk>.vdi
```

**Téléchargement de l'ISO et attachement au SATA**

```bash
# Téléchargement de l'ISO
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.2.0-amd64-netinst.iso
VBoxManage storageattach "Born2BeRootDebian" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium <path-to-iso>.iso
```

**Configuration de l'ordre de boot**

```bash
VBoxManage modifyvm "Born2BeRootDebian" --boot1 dvd --boot2 disk --boot3 none --boot4 none
```

**Accès RDP et démarrage**

```bash
VBoxManage modifyvm "Born2BeRootDebian" --vrde on --vrdemulticon on --vrdeport 10001
VBoxHeadless --startvm "Born2BeRootDebian"
```

> Ma configuration est en virtualisation imbriquée donc je dois activer la fonction via la commande :
>
> `VBoxManage modifyvm "Born2BeRootDebian" --nested-hw-virt on`

## Introduction

Dans le cadre de l'utilisation de cette "documentation", je vais donner quelques règles :

**Syntaxe des commandes**

Les commandes données et préfixées `sudo` sont des commandes avec une élévation de droit requise pour les réaliser en utilisateur
non-root. Ces commandes peuvent être fait sans `sudo` en tant que `root`.

> D'ailleurs, elle se seront obligatoirement faire sans `sudo` et en `root` avant l'installation et le paramétrage de `sudo`.

_exemples_

```bash
# commande obligeant être root
sudo useradd -G user42,sudo xbeheydt
# commande somme toute fois accessible pour tous dans un dossier accessible
ls -la
```

> Les commandes en `root`pourront être réalisées via une élévation de droits en préfixant la commande avec `sudo` en étant connecté
avec un utilisateur normal fesant parti du groupe `sudo` (ou fesant parti de la config sudoers).

## Installation du système

L'installation est assez simple, car on va configurer les locales et le claviers tout d'abord. Puis paramétrer l'utilisateur `root` et notre propre utilisateur.

Puis faire le partitionnement (sous-chap suivant) et installer les paquets de base.

### Partitionnement

Il y aura au moins 2 partitions:

- Une parition en EXT4 de boot.
- Une partition physique encrypté contenant un LVM.

**Detail**

```
sda
|
+--- sda1 -> /boot 512M - minimum for UEFI
|
+--- sda2 header encrypt data ?
|
+--- sda5
	|
	+--- sda5_crypt (volume physique encrypté)
	        |
			|	(subsystem LVM Group)
			|
			+--- xb--vg-root		/root
			|
			+--- xb--vg-swap		[SWAP]
			|
			+--- xb--vg-home		/home
			|
			+--- xb--vg-var		/var
			|
			+--- xb--vg-srv		/srv
			|
			+--- xb--vg-tmp		/tmp
			|
			+--- xb--vg-var-log	/var/log
```

> J'intègre directement le layout des volumes logiques du bonus. Car à priori rien ne m'interdit de le faire immédiatement. Soit la mention "2 partitions minimum".

## Configuration du système

Dans notre projet de création de serveur virtuel, nous avons besoin de configurer plusieurs choses :

- [X] Installation des paquets de base requis et optionnels.
- [X] AppArmor.
- [X] Modification de l'éditeur par défaut.
- [X] Modification du nom de machine, le `hostname`.
- [X] Le serveur ssh, port et restriction root.
- [X] Le firewall activé uniquement pour les services mentionnés.
- [X] Configuration de `sudo`.

### Installation des paquets de base requis et optionnels

```bash
sudo apt update
sudo apt upgrade
sudo apt install vim ufw openssh-server sudo curl wget
```

## AppArmor

Dans le sujet, nous devons veiller à ce que `AppAmor` soit bien actif. Pour vérifier le status, nous pouvons lancer la commande `sudo aa-status`.


Pour rappel `AppArmor` est un logiciel de réglage fin de sécurité. Cela gère les droits et accès des utilisateurs et des applications en complément des règle et système de sécurité de base de GNU/Linux.

> A la différence de `SELinux` qui est réputé pour

### Modification de l'editeur par défaut [OPTION]

Sous Debian, l'éditeur par défaut est `nano`. Pour une question de confort personnel, j'utilise `vim`. On va donc installer
et configurer l'éditeur par défaut comme étant `vim`

```bash
# Modification de l'éditeur par défaut
sudo update-alternatives --config editor
# Puis choisir l'éditeur
```

### Modification du nom de machine

Alors pôur faire cela plusieurs méthodes existent, via la commande `hostname` ou via un outil fournit avec `systemd`
la commande `hostnamectl`._Personnallement je le fais à la main et je reboot_.

**ALaMano**

Modifier le fichier `/etc/hostname` et remplacer le nom par le nouveau. Ici on met en place le nom "canonique".

Puis modifier le fichier `/etc/hosts` à la ligne fesant référence à `127.0.1.1` et mettre le même nom de machine.
Cette adresse permet de mapper le nom d'hôte à l'adresse IP (une quasi loopback) dans le cas où il y a pas d'accès réseau.
Ce fichier permet de mapper des nom de machine a des adresses un peu comme un DNS local figé ou plutôt il va prendre le relais en cas de non accès à un DNS.
Comme les system `*UNIX` fonctionne sur des principe de réseau, le système cherchera à faire une résolution du nom de machine vis à vis d'une ip et on seconde
le loopback via l'adresse `127.0.1.1` au nom de machine que l'on utilise.

> Un script de modification du nom de machine à `./scripts/change-hostname.sh`.

### Serveur SSH

**Configuration du serveur**

Le service s'appel `sshd`. La configuration minimal demandée est port `4242` et pas de login pour root.
Voici un patch à appliquer au fichier `/etc/ssh/sshd_config`:

```diff
15c15
< #Port 22
---
> Port 4242
34c34
< #PermitRootLogin prohibit-password
---
> PermitRootLogin no
```

> Le fichier de patch est à `./configs/sshd_config.patch`.

```bash
sudo patch /etc/ssh/sshd_config <path-to-patch-file>
```

> Il est possible de modifier à la main le fichier `sudo vim /etc/ssh/sshd_config`.

Il faut aussi redémarrer le service pour qu'il prenne en compte la modification, voir la section suivante.

**Manipulation du service**

Le système utilise le système d'init `systemd`. Il permet de donc de gérer les services du système.
Voici quelques commandes à propos :

```bash
sudo systemctl status sshd # le status peu être utilisable en utilisateur normal
sudo systemctl restart sshd
sudo systemctl enable sshd
sudo systemctl disable sshd
sudo systemctl start sshd
sudo systemctl stop sshd
```

> `sshd` est aussi un alias du vrai nom de service `ssh.service`

### Configuration du firewall

Dans notre projet l'application de manipulmation du firewall est `ufw`.

**Installation**

```bash
sudo apt install ufw
```

> Vérification que le service est actif `systemctl status ufw`

**Configuration**

```bash
# Activation
sudo ufw enable
# Blocage des connexions entrantes
sudo ufw default deny
# Ouverture en TCP du port 4242 pour le serveur ssh
sudo ufw allow 4242/tcp
# Vérification des règles
sudo ufw status numbered
```

### Configuration de sudo

- [X] Limitation à 3 essais de mots de passe
- [X] Personnalisation du message d'erreur
- [X] Logging des action en `input` et `output`
- [X] Mode TTY activé
- [X] Restriction des paths

L'ensemble des configurations sont effectuées dans le fichier `/etc/sudoers`, mais pour des questions de sécurité et éviter de bloqué le système, nous devons editer ce fichier via la commande `visudo`.

**Limitation à 3 essais de mots de passe**

La limitation à 3 essais de mot de pass se défini avec `Defaults passwd_tries=3`.

**Personnalisation du message d'erreur**

La personnalisation de message d'erreur se défini avec `Defaults badpass_message="<your-message>"`

**Logging des action en `input` et `output`**

La mise en place du logging pour `sudo` se fait :

- Pour l'enregistrement des `input` et `output` via :
	```bash
	Defaults log_input
	Defaults log_output
	```
- Soit on enregistre de manière "brute" via `Defaults iolog_dir=/var/log/sudo`
- Mais on peut aussi sortir un fichier "human-readable" via `Defaults logfile=/var/log/sudo/sudo.log`
**Mode TTY activé**

L'activation du mode TTY se défini par `Default requiretty`.

**Restriction des paths**

On peut définir le path utilisé lors de l'appel `sudo` via `Default secure_path="<your-paths>:<...>"`

**Configuration complète**

Un fichier de patch est disponible `./configs/sudoers/patch`.

```diff
8a9
> Defaults      requiretty
11c12,18
< Defaults      secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
---
> Defaults      log_output
> Defaults      log_input
> Defaults      iolog_dir=/var/log/sudo
> Defaults      logfile=/var/log/sudo/sudo.log
> Defaults      badpass_message="Ohhhh no you don't remember your password ??? NOOB !!!"
> Defaults      passwd_tries=3> Defaults      secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
```

> Avant la configuration, il est possible de voir la conf actuelle, via la commande `sudo -ll`. Pour reset de temps d'autorisation on peut lancer la commande `sudo -k`.

### Configuration des utilisateurs et de la sécurité

- [X] Modification des groupes par défaut de notre utilisateur courant
- [X] Règle d'expiration des mots de passe
- [X] Règles de format des mots de passe

**Modification des groupes par défaut de notre utilisateur courant**

```bash
# modification du groupe xbeheydt en user42
sudo groupmod -n user42 xbeheydt
# Modification des groupes de notre utilisateur
sudo usermod -g xbeheydt42 -G sudo xbeheydt
```

> Il faut se relog pour voir la modification via la commande `groups`.
Il existe plusieur methode via `deluser`, `delgroup` ou encore `gpasswd`.
Et oui pourquoi faire simple quand on peut faire compliqué. (histoire de retrocomp)

**Règle d'expiration des mots de passes**

Afin d'établir une règle d'expiration des mots de passe, nous pouvons modifier le fichier `/etc/login.defs`, tel que :

```diff
160,161c160,161
< PASS_MAX_DAYS 99999
< PASS_MIN_DAYS 0
---
> PASS_MAX_DAYS 30
> PASS_MIN_DAYS 2
```

> Attention, la modification ne touche pas les utilisateurs déjà créés. Il faut donc faire la modification.

```bash
# exemple pour mon utilisateur, mais a faire pour tous
sudo chage -m 2 -M 30 -W 7 xbeheydt
# Application des règles pour root
sudo chage -m 2 -M 30 -W 7 root
```

**Règles des formats de mots de passe**

Pour la gestion fine des format des mots de passe, nous aurons besoin d'un module PAM `pam_pwquality`.

> Un autre et plus ancien module existait `pam_cracklib`, celui-ci est repris par `pam_pwquality` en y ajoutant des fonctions supplémentaires. Je vais donc prendre le plus récent.

```bash
# Installation de la lib cracklib
sudo apt install libpam-pwquality
```

Il faut ensuite établir les règles dans le fichier `/etc/pam.d/common-passwd`.

- 10 caractères -> `minlen=10`
- 1 majuscule minimum -> `ucredit=-1`
- 1 chiffre minimum -> `dcredit=-1`
- 3 caractères identiques consécutifs -> `maxrepeat=3`

## Rappel des commandes

**Création et suppression d'un groupe**

```bash
# création
sudo groupadd <group-name>
# suppression d'un groupe
sudo group^del <group-name>
```

**Création et suppression d'un nouvel utilisateur**

```bash
# Création d'un utilisateur
sudo useradd -d /home/test --create-home -N -s /bin/bash -G user42,sudo <username>
# suppression d'un utilisateur
sudo userdel -r <username>
```

**Vérification des partitions, ram et disque**

```bash
# partitions
lsblk
# RAM
free -m
# disk
df
```

**Modification des dates de mot de passe**

```bash
# Voir les dates actuelles
sudo chage -l <username>
# Exemple de modification
sudo chage -m 2 -M 30 -W 7 <username>
```

**Vérification du status d'AppArmor**

```bash
sudo aa-status
```

## Bonus

- [X] Partitions étendues
- [X] Wordpress
- [X] Service complémentaire

**Partitions étendues**

Le système de partition a été fait dès l'installation.

### WordPress

Le sujet demande de mettre en place le serveur web `lightttpd` avec `WordPress` et une base de données sous `MariaDB`.

**Installation de Lighttpd**

```bash
sudo apt update
sudo apt install lighttpd
```

**Configuration de Lighttpd**

Nous allons avoir besoin de plusieurs modules de `lighttpd` et d'une petite configuration pour faire fonctionner `WordPress`

Pour les modules :

- `sudo lighty-enable-mode fastcgi`
- `sudo lighty-enable-mode fastcgi-php`
- `sudo lighty-enable-mode accesslog`

La configuration dans le fichier `/etc/lighttpd/lighttpd.conf` :

```diff
5a6
>       "mod_rewrite",
8,9c9,10
< server.document-root        = "/var/www/html"
< server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
---
> server.document-root        = "/srv/www/html"
> server.upload-dirs          = ( "/srv/cache/lighttpd/uploads" )
```

> Nous remplaçons les path de fichiers documents vers notre dossier `srv`.
>
> Et nous activons le module réécriture dans le cadre des réécriture d'URL de wordpress.
>
> Nous aurions pu créer une host à part pour wordpress, mais comme le serveur est dédié alors au plus simple.

**Lancement du service**

```bash
sudo systemctl enbale lighttpd.service
sudo systemctl restart lighttpd.service
```

**Installation de MariaDB**

```bash
sudo apt update
sudo apt install mariadb-server mariadb-client
```

**Création d'un utilisateur et d'une base de données**

Nous allons créer un utilisateur et une base de données pour WordPress.

```bash
# connexion à mariaDB via le client local
sudo mariadb -u root -p
```

```sql
# Création de la base
CREATE DATABASE wpdb;

# Création d'un utilisateur avec les accès à la base
GRANT ALL ON wpdb.* TO 'wupuser'@'localhost' IDENTIFIED BY 'your-password';
FLUSH PRIVILEGES;
EXIT
```

> Le service est actif de base après l'installation. Donc pas besoin de l'activé ou de le lancer.

Wordpress fonctionne sous PHP (et de modules particuliers de PHP) et à besoin d'un base de données (d'où l'installation de MariaDB).

**Installation de PHP**

```bash
sudo apt install php php-json php-zip php-mbstring php-gd php-intl php-cgi php-mysql php-pear php-xmlrpc php-mcrypt
```

**Installation et configuration de Worpress**

Nous allons installer Wordpress depuis les sources à la dernières versions et non celle des repos Debian.

```bash
cd /tmp
wget http://wordpress.org/latest.tar.gz
sudo mkdir -p /srv/www/html
tar -xzvf latest.tar.gz
sudo cp -R wordpress/* /srv/www/html
sudo rm -rf /srv/www/html/*.index.html
sudo cp /srv/www/html/wp-config-sample.php /srv/www/html/wp-config.php
```

Nous allons donc éditer le fichier de configuration de Wordpress - `/srv/www/html/wp-config.php` :

```diff
23c23
< define( 'DB_NAME', 'database_name_here' );
---
> define( 'DB_NAME', 'wpdb' );
26c26
< define( 'DB_USER', 'username_here' );
---
> define( 'DB_USER', 'wpuser' );
29c29
< define( 'DB_PASSWORD', 'password_here' );
---
> define( 'DB_PASSWORD', 'wpdbpass' );
```

Afin que lighttpd puisse bien accéder aux fichiers il faut que les fichiers Wordpress soit en utilisateur et groupe `www-data` qui est l'utilisateur largement admis pour les services webserver. On va aussi modifier les droits des fichiers :

```bash
sudo chown -R www-data:www-data /srv/www/html/
sudo chmod -R 755 /srv/www/html/
```

> Pour bien prendre les fichiers, on peut relancer lighttpd `sudo systemctl restart lighttpd.service`.

### Service complémentaire

Mon choix va se porter sur un service de monitoring et ici on va monitorer la base de données. J'aurai pu prendre quelques chose de plus commun comme un générateur de certificat pour le `HTTPS` via let'sencrypt, mais j'ai décidé que non - bien que ce soit nécessaire de nos jours le `HTTPS`.

Je vais donc mettre en place, pas un, mais deux services :

- `prometheus` pour un genre de cron qui va faire l'audit des services à monitorer.
- `grafana` comme frontend d'affichage de stats de nos monitorings.


**Installation et configuration de prometheus**

```bash
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo mkdir /srv/lib/prometheus
for i in rules rules.d files_sd; do sudo mkdir -p /etc/prometheus/${i}; done
mkdir -p /tmp/prometheus && cd /tmp/prometheus
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
  | grep browser_download_url \
  | grep linux-amd64 \
  | cut -d '"' -f 4 \
  | wget -qi -
tar xvf prometheus*.tar.gz
cd prometheus*/
sudo mv prometheus promtool /usr/local/bin/
sudo mv prometheus.yml  /etc/prometheus/prometheus.yml
sudo mv consoles/ console_libraries/ /etc/prometheus/
cd ~/
rm -rf /tmp/prometheus
```

De base l'accès web n'est pas actif avec une authentification, on va donc créer cela :

_script python pour générer un mot de passe encrypté en http basic auth_

```bash
sudo apt install python3 python3-bcrypt
```

```python
#!/usr/bin/env python3
import getpass
import bcrypt

password = getpass.getpass("password: ")
hashed_password = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
print(hashed_password.decode())
```

```bash
chmod +x <your-python-script>.py
./<your-python-script>.py <your-password>
```

_Fichier de configuration de l'auth web de prometheus_

Il se trouvera `/etc/prometheus/web.yml` :

```yaml
basic_auth_users:
	<user-name>: <password-encrypted-with-python-script>
```

_Création du service prometheus_

Le fichier sera `/etc/systemd/system/prometheus.service` :

```
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Environment="GOMAXPROCS=1"
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/srv/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.config.file=/etc/prometheus/web.yml \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
```

> `GOMAXPROC=1` car 1 seul vCPU.

_Ouverture du port_

```bash
sudo ufw allow 9090/tcp
```

_Actualisation des permissions des dossiers_

```bash
for i in rules rules.d files_sd; do sudo chown -R prometheus:prometheus /etc/prometheus/${i}; done
for i in rules rules.d files_sd; do sudo chmod -R 775 /etc/prometheus/${i}; done
sudo chown -R prometheus:prometheus /srv/lib/prometheus/
```

_Lancement du service_

```bash
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
```

_Exporter de MySQL_

Ici on parle de MySQL mais c'est compatible avec MariaDB...

```bash
curl -s https://api.github.com/repos/prometheus/mysqld_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
tar xvf mysqld_exporter*.tar.gz
sudo mv  mysqld_exporter-*.linux-amd64/mysqld_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/mysqld_exporter
rm -rf mysqld_exporter*.linux-amd64
```

_Ajout d'un utilisateur à la base et d'une base pour l'export_

```bash
sudo mariadb -u root -p
```

```sql
CREATE USER 'mysqld_exporter'@'localhost' IDENTIFIED BY '<your-password>' WITH MAX_USER_CONNECTIONS 2;
# MAX_USER_CONNECTIONS 2 pour éviter de surcharger le serveur
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
FLUSH PRIVILEGES;
EXIT
```

_Configuration de l'exporter_

Le fichier sera `/etc/.mysqld_exporter` : 

```ini
[client]
user=mysqld_exporter
password=<your-password>
```

```bash
sudo chown root:prometheus /etc/.mysqld_exporter.cnf
```

_Création du service d'export_

Le fichier sera `/etc/systemd/system/mysql_exporter.service` :

```
[Unit]
Description=Prometheus MySQL Exporter
After=network.target
User=prometheus
Group=prometheus

[Service]
Type=simple
Restart=always
ExecStart=/usr/local/bin/mysqld_exporter \
--config.my-cnf /etc/.mysqld_exporter.cnf \
--collect.global_status \
--collect.info_schema.innodb_metrics \
--collect.auto_increment.columns \
--collect.info_schema.processlist \
--collect.binlog_size \
--collect.info_schema.tablestats \
--collect.global_variables \
--collect.info_schema.query_response_time \
--collect.info_schema.userstats \
--collect.info_schema.tables \
--collect.perf_schema.tablelocks \
--collect.perf_schema.file_events \
--collect.perf_schema.eventswaits \
--collect.perf_schema.indexiowaits \
--collect.perf_schema.tableiowaits \
--collect.slave_status \
--web.listen-address=0.0.0.0:9104

[Install]
WantedBy=multi-user.target
```

_Lancement du service_

```bash
sudo systemctl daemon-reload
sudo systemctl enable mysql_exporter
sudo systemctl start mysql_exporter
```

_Ajout de la configuration à prometheus_

Le fichier à modifier est `/etc/prometheus/prometheus.yml` :

```yaml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "wp_db"
    static_configs:
      - targets: ["localhost:9104"]
        labels:
		  alias: wpbd1
```

**Installation et configuration de Grafana**

```bash
sudo apt-get install -y gnupg2 curl software-properties-common
curl https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt-get update
sudo apt-get -y install grafana
```

_Lancement du service_

```bash
sudo systemctl enable --now grafana-server
```

_Ouverture du port_


```bash
sudo ufw allow 3000/tcp
```

> J'ai pris un exemple de mise en forme pour l'affichage de stats `https://raw.githubusercontent.com/percona/grafana-dashboards/master/dashboards/MySQL_Overview.json`.