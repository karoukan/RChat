# RChat

Plateforme de chat communautaire auto-hébergeable, construite avec Elixir et Phoenix LiveView.

Communautés, salons, rôles : la grammaire d'interface que tout le monde connaît, dans un outil open source que votre communauté héberge elle-même. Un seul binaire, une base SQLite, aucune dépendance externe.

Projet en développement actif, pas encore prêt pour un usage réel.

## Auto-hébergement

Prérequis : Docker et un volume pour les données.

Générer la configuration une seule fois :

```sh
mkdir -p ~/rchat
printf 'SECRET_KEY_BASE=%s\nPHX_HOST=chat.example.com\n' "$(openssl rand -base64 48 | tr -d '\n')" > ~/rchat/rchat.env
chmod 600 ~/rchat/rchat.env
```

Puis lancer le serveur :

```sh
docker build -t rchat .
docker run -d --name rchat \
  --env-file ~/rchat/rchat.env \
  -p 4000:4000 \
  -v rchat_data:/data \
  --restart unless-stopped \
  rchat
```

L'application écoute sur le port 4000. La base SQLite vit dans le volume `rchat_data`, les migrations s'exécutent automatiquement au démarrage.

`SECRET_KEY_BASE` signe les sessions : elle se génère une fois et se conserve. La régénérer déconnecte tous les utilisateurs. Ne la passez jamais en clair sur la ligne de commande.

Variables reconnues :

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `SECRET_KEY_BASE` | obligatoire | Signature des sessions et cookies |
| `PHX_HOST` | `localhost` | Nom de domaine public |
| `PORT` | `4000` | Port HTTP |
| `DATABASE_PATH` | `/data/rchat.db` | Chemin de la base SQLite |

## Développement

```sh
mix setup
mix phx.server
```

L'application est disponible sur [localhost:4000](http://localhost:4000).

```sh
mix test
```

## Licence

À définir.
