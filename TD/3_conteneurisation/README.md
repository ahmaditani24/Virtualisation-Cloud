# TD 3 : Conteneurisation

Environnement : Ubuntu sous WSL 2, Docker Desktop (intégration WSL activée).

---

## Partie 1 : Une impression de déjà vu (`frontend/`)

### Fichiers

- `index.html` : page web simple (HTML + un peu de CSS).
- `Dockerfile` :

```dockerfile
FROM nginx:latest
LABEL author="ahmad"

COPY index.html /usr/share/nginx/html/

EXPOSE 80
```

### Commandes

```bash
docker build . -t mon-frontend
docker run -p 8080:80 mon-frontend
```

`-p 8080:80` redirige le port 8080 de ma machine vers le port 80 du conteneur. La page est visible sur http://localhost:8080.

### Question (étape 5) : quel est le point d'entrée de l'application et quelle commande est exécutée au démarrage ?

Mon Dockerfile ne contient ni `ENTRYPOINT` ni `CMD` : il hérite donc de ceux de l'image de base `nginx`. Avec `docker inspect nginx:latest`, on voit :

- `Entrypoint` : `/docker-entrypoint.sh`, un script qui prépare la configuration de nginx (on le voit dans les logs au démarrage : `/docker-entrypoint.sh: Configuration complete; ready for start up`) ;
- `Cmd` : `nginx -g daemon off;`, qui lance le serveur nginx au premier plan.

Le conteneur exécute donc `/docker-entrypoint.sh nginx -g "daemon off;"`. nginx doit rester au premier plan (`daemon off`) : si le processus principal s'arrête, le conteneur s'arrête aussi.

### Question (étape 9) : on modifie `index.html` et on redéploie. Que peut-on observer ?

- Si on relance seulement `docker run` sans refaire `docker build`, la page **ne change pas** : le conteneur est créé à partir de l'ancienne image, qui contient l'ancienne version de `index.html`.
- Il faut **reconstruire l'image** (`docker build`) puis relancer un conteneur pour voir la modification.

Une image est une **photo figée** des fichiers au moment du build : elle est immuable. Le `COPY` copie le fichier dans l'image, il ne crée pas de lien avec le fichier sur ma machine.
On observe aussi que le deuxième build est très rapide : Docker réutilise les couches déjà construites (cache) et ne refait que la couche `COPY`.

---

## Partie 2 : Explorer ce micro-environnement (`backend/`)

### Dockerfile

```dockerfile
FROM debian:latest
LABEL author="ahmad"

RUN apt-get update && apt-get install -y \
    bash \
    htop \
    vim \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

ENV OWNER=Ahmad

RUN useradd nonroot
USER nonroot

CMD ["sleep", "3600"]
```

- `netstat` est fourni par le paquet `net-tools`.
- `sleep 3600` garde le conteneur en vie : Debian n'a pas de processus qui tourne en continu par défaut.

### Commandes

```bash
docker build . -t toolbox
docker run --name toolbox-ctn toolbox
docker exec -it toolbox-ctn /bin/bash   # dans un 2e terminal
```

### Question : pourquoi n'a-t-on pas utilisé `EXPOSE` ?

`EXPOSE` documente le port sur lequel l'application **écoute** pour recevoir des connexions (comme nginx sur le port 80). La toolbox ne fait tourner aucun service réseau : elle exécute seulement `sleep`, et on y entre avec `docker exec`. Il n'y a donc aucun port à exposer.

### Question : `curl` depuis la toolbox vers le frontend, que constate-t-on ?

Depuis la toolbox, `curl http://host.docker.internal:8080` renvoie bien le HTML de ma page. Dans les logs nginx du frontend, la requête apparaît :

```
172.17.0.1 - - [...] "GET / HTTP/1.1" 200 512 "-" "curl/8.14.1"
```

- Les conteneurs sont **isolés** (chacun a son système de fichiers et ses processus), mais ils peuvent **communiquer par le réseau**.
- La requête passe par la machine hôte et le port publié avec `-p 8080:80`.
- `172.17.0.1` est l'adresse de la passerelle du réseau Docker (l'interface `docker0`).

Remarque : avec Docker Desktop, l'interface `docker0` n'est pas visible dans Ubuntu (`ip -4 addr show`), car le moteur Docker tourne dans sa propre machine virtuelle. On utilise donc le nom spécial `host.docker.internal`, qui désigne la machine hôte vue depuis un conteneur.

### Question : gestion des droits, qu'en déduit-on ?

| | Sans `USER` | Avec `USER nonroot` |
|---|---|---|
| `whoami` | `root` | `nonroot` |
| `apt-get install curl` | installé | `Permission denied` |

- Par défaut, un conteneur s'exécute en **root**, avec tous les droits à l'intérieur du conteneur.
- C'est un **risque de sécurité** : si l'application est compromise, l'attaquant hérite de ces droits (installer des outils, modifier le système, tenter de sortir du conteneur).
- Avec un utilisateur non-root, on applique le **principe du moindre privilège** : l'utilisateur ne peut plus modifier le système.
- Conséquence : tout ce dont le conteneur a besoin doit être installé **au build**, dans un `RUN` placé **avant** l'instruction `USER`.

---

## Partie 3 : Sauvegardons ce joli frontend (Artifact Registry)

À compléter.