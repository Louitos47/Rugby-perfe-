# Déployer les notifications push (send-push)

Objectif : quand le staff publie une annonce, tous les joueurs de l'équipe
reçoivent une notification sur leur téléphone, comme un SMS.

## Étape 1 — Régénérer la clé OneSignal (important !)

L'ancienne clé était visible dans le code public : n'importe qui a pu la copier.

1. Va sur https://onesignal.com → ton app Rugby Perf
2. Settings → Keys & IDs
3. Clique sur « Regenerate » à côté de la REST API Key
4. Copie la nouvelle clé (elle commence par `os_v2_app_...`)

## Étape 2 — Créer la fonction dans Supabase

1. Va sur https://supabase.com/dashboard → ton projet Rugby Perf
2. Menu de gauche → **Edge Functions**
3. Clique **Deploy a new function** → **Via Editor**
4. Nomme-la exactement : `send-push`
5. Efface le code d'exemple et colle tout le contenu du fichier `index.ts`
   (dans ce même dossier)
6. Clique **Deploy function**

## Étape 3 — Ajouter la clé secrète

1. Toujours dans Edge Functions → onglet **Secrets**
   (ou Settings → Edge Functions → Secrets)
2. Ajoute un secret :
   - Nom : `ONESIGNAL_API_KEY`
   - Valeur : la nouvelle clé copiée à l'étape 1
3. Sauvegarde

## Étape 4 — Tester

1. Déploie la dernière version de `index.html` sur Netlify
2. Connecte-toi avec un compte **joueur** sur un téléphone :
   - Sur iPhone : il faut d'abord ajouter l'app à l'écran d'accueil
     (Safari → bouton partager → « Sur l'écran d'accueil »), puis l'ouvrir
     depuis l'icône et accepter les notifications
   - Sur Android : ouvrir le site et accepter les notifications suffit
3. Connecte-toi avec ton compte **manager** (autre appareil ou navigateur)
4. Publie une annonce → le joueur doit recevoir la notification 🎉

## Comment ça marche

- L'app appelle la fonction `send-push` avec le compte connecté
- La fonction vérifie que c'est bien un manager ou un prépa de l'équipe
- Elle envoie la notification via OneSignal aux joueurs tagués `team_id`
- La clé secrète ne quitte jamais le serveur Supabase

## À savoir (limite Apple)

Sur iPhone, les notifications web n'arrivent QUE si l'app a été ajoutée à
l'écran d'accueil et ouverte au moins une fois depuis l'icône. C'est une
restriction d'Apple, pas de l'app. Pense à l'expliquer à tes joueurs
(un petit tuto dans l'app peut aider — demande-moi si tu le veux).
