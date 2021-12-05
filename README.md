# 42 Cursus - Born2BeRoot

Création d'un serveur virtuel sur VirtualBox.

Le système sera sous GNU/Linux Debian 64Bits en version stable.

## Préface

Dans le cadre de l'utilisation de cette "documentation", je vais donner quelques règles :

**Syntaxe des commandes**

Les commandes données et préfixées `sudo` sont des commandes avec une élévation de droit requise pour les réaliser en utilisateur
non-root. Ces commandes peuvent être fait sans `sudo`en tant que `root`.

> D'ailleurs, ellese seront obligatoirement faire sans `sudo` et en `root` avant l'installation et le paramétrage de `sudo`.

_exemples_

```bash
# commande obligeant être root
sudo useradd -G xbeheydt42,sudo xbeheydt
# commande somme toute fois accessible pour tous dans un dossier accessible
ls -la
```

> Les commandes en `root`pourront être réalisées via une élévation de droits en préfixant la commande avec `sudo` en étant connecté
avec un utilisateur normal fesant parti du groupe `sudo` (ou fesant parti de la config sudoers).

## Installation du système

L'installation est assez simple, car on va configurer les locales et le claviers tout d'abord.
Puis faire le partitionnement (sous-chap suivant) et installer les paquets de base.

Pour les paquest de bases, le système de base et le serveur `ssh`et c'est tout pour le moment.

### Partitionnement

Il y aura au moins 2 partitions:

- Une parition en EXT4 de boot.
- Une partition physique encrypté contenant un LVM.

**Detail**

```
sda
|
+--- sda1 -> /boot 500M
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
> J'intègre directement le layout des volumes logiques du bonus. Car a priori rien n'imterdit de le faire immédiatement.
Soit la mention "2 partition minimum".

## Configuration du système

Dans notre projet de création de serveur virtuel, nous avons besoin de configurer plusieurs choses :

- [X] Modification du nom de machine, le `hostname`.
- [X] Le serveur ssh, port et restriction root.
- [X] Le firewall activé uniquement pour les services mentionnés.

### Moficiation de l'editeur par défaut

Sous Debian, l'éditeur par défaut est `nano`. Pour une question de confort personnel, j'utilise `vim`. On va donc installer
et configurer l'éditeur par défaut comme étant `vim`

```bash
# Installation de vim
sudo apt install vim
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
Cette adresse permet de mapper le nom d'hôte à l'adresse IP (une quasi loopback) dans le cas ou il y a pas d'accès réseau.
Ce fichier permet de mapper des nom de machine a des adresses un peu comme un DNS local figé ou plutôt il va prendre le relais en cas de non accès à un DNS.
Comme les system `*UNIX` fonctionnesur des principe de réseau, le système cherchera à faire une résolution du nom de machine vis à vis d'une ip et on seconde
le loopback via l'adresse `127.0.1.1` au nom de machine que l'on utilise.

### Serveur SSH

**Installation**

Dansl e cas où l'installation n'est pas active sur le serveur, il faut donc installer les paquets :

```bash
# Installation de la partie client
sudo apt install openssh-client
# la partie serveur
sudo apt install openssh-server
```

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

```bash
sudo patch /etc/ssh/sshd_config <path-to-patch-file>
```

> Il est possible de modifier à la main le fichier `sudo vim /etc/ssh/sshd_config`.
Il faut aussi redémarrer le service pour qu'il prenne en compte la modification, voir la section suivante.

**Manipulmation du service**

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
# Blocage des connexion entrante
sudo ufw default deny
# or
sudo ufw default incomming
# Ouverture en TCP du port 4242 pour le serveur ssh
sudo ufw allow 4242/tcp
# Vérification des règles
sudo ufw status verbose
```

## Configuration des utilisateurs et de la sécurité

Sous Debian lors de l'installation, il nous est demander de configurer le mot de passe pour `root` et de créer un utilisateur.

- [X] Utilisation de `root` avant installation de `sudo`.
- [ ] Gestion des utilisateurs et règles des mots de passe
- [ ] Installation et configuration de `sudo`.

### Utilisation de root

Avant d'installer et configurer `sudo`, nous allons devoir passer par le compte `root` pour faire nos premiers paramétrages.
Ainsi avoir les bonnes variable d'env et accès à tout les `sbin, il faut :

```bash
# Ne pas faire car pas les $SUPATH
su
# A faire pour avoir les $SUPATH
su - root
```

### Gestions des utilisateurs et règles sur les mots de passe

Lors de l'installation de Debian, il est commun qu'un utilisateur normal soit créé.
De base celui-ci dispose d'un lot de groupe dont son propre groupe portant le même nom que son login.

**Modification du nom du groupe**

```bash
sudo groupmod -n xbeheydt42 xbeheydt
```

**Modification des groupes d'un utilisateur**

```bash
sudo usermod -g xbeheydt42 -G sudo xbeheydt
```

> Il faut se relog pour voir la modification via la commande `groups`.
Il existe plusieur methode via `deluser`, `delgroup` ou encore `gpasswd`.
Et oui pourquoi faire simple quand on peut faire compliqué. (histoire de retrocomp)

**Règle d'expiration des mots de passes**

Afin d'établir une règle d'expiration des mots de passe, nous pouvons modifier le fichier `/etc/login.defs`, tel que :

```diff
160,161c160,161
< PASS_MAX_DAYS 30
< PASS_MIN_DAYS 2
< PASS_WARN_AGE 7 
---
> PASS_MAX_DAYS 99999
> PASS_MIN_DAYS 0
> PASS_WARN_AGE 7 
```

> Attention, la modification ne touche pas les utilisateurs déjà créés. Il faut donc faire la modification.

```bash
# exemple pour mon utilisateur, mais a faire pour tous
sudo chage -m 2 -m 30 -W 76 xbeheydt
```

**Règles des formats de mots de passe**

Le projet demande des règles pour les utilisateurs normaux et d'autres règles pour root.
Pour cela nous utiliserons un module pam appelé `pam-cracklib`.

```bash
# Installation de la lib cracklib
sudo apt install libpam-cracklib
```

Il faut ensuite établir les règles dans le fichier `/etc/pam.d/common-passwd`, comme :

### Installation et configuration de sudo

`sudo` est une alternative plus sûre que `su` pour effectuer des commandes avec privilèges.
`su` lance un shell `root` permettant à toutes les autres commandes d'accéder à `root`. `sudo` lui ne permet l'élévation
uniquement à la commande préfixé, donc les pipes de commandes ne pourrons pas avoir accès à l'élévation.
Il est possible avec `sudo` d'avori un shell interectif à la manière de la commande `su - root` soit `sudo -i`.

`sudo` ne permet pas uniquement de faire des commandes en élévation de droit (`root`) mais aussi avec d'autres utilisateurs.
Cela demande une configuration complémentaire.

**Installation**

```bash
sudo apt install sudo
```

**Configuration**

La configuration de `sudo` sera appliquée au groupe affilié `sudo`.

- [ ] Authentification limité à 3 essais.
- [ ] Personnalisation du message d'erreur suite à un mauvais mot de passe.
- [ ] Archivage des actions (input, output) sous `sudo` dans la journalisation `/var/log/sudo`
- [ ] Le mode `TTY` activé.
- [ ] Les paths de `sudo`restreints.

> Avant la configuration, il est possible de voir la conf actuelle, via la commande `sudo -ll`. La configuration doit 
