# Profils et accès social natifs — 7 octobre 2026

## Profil

La photo est choisie avec PhotosPicker, préparée hors du thread principal en JPEG (maximum 800 pixels et 2 Mio), puis envoyée lors de l’enregistrement. Le bucket privé existant `friend-avatars` et le chemin `userId/avatar.jpg` restent compatibles avec React Native. Le profil est modifié uniquement après l’upload ; la réponse serveur est vérifiée. Retirer la photo efface `avatar_path`, sans supprimer un objet éventuellement remplacé par un autre appareil. Les images déjà synchronisées ont un cache séparé par compte.

## Conversations

`ChatRepository` utilise le SDK Supabase déjà installé. L’abonnement à `friend_messages` est filtré par `link_id` ou `group_id`. Un événement déclenche `ConversationLibrary.refresh()` : les données ne sont pas injectées directement dans le cache. La fusion et la file hors ligne existantes restent utilisées. Les événements reçus pendant une synchronisation demandent une nouvelle lecture après sa fin. Fermeture, arrière-plan, perte de réseau et changement de compte arrêtent l’abonnement ; le retour relance la connexion. Une lecture périodique reste disponible si Realtime est indisponible.

Si la table n’est pas publiée dans Supabase Realtime, appliquer `Supabase/enable-chat-realtime.sql` ou activer la table dans le tableau de bord. Le SQL est fourni, pas exécuté. Les policies existantes restent en place. Les suppressions par modération utilisent déjà `deleted_at` et passent donc par des événements UPDATE.

## Administration

L’écran « Comptes · espace amis » utilise `friend_profiles`, `social_suspensions`, `app_admins` et les RPC existantes `suspend_social_member`/`unsuspend_social_member`. Pagination par 50 profils, recherche dans les profils chargés. Motif requis, durée 24 heures/7 jours/sans date de fin et confirmation native. L’état change uniquement après réponse et lecture de confirmation serveur. L’administrateur courant et les autres administrateurs sont protégés. Il s’agit d’une suspension des échanges sociaux, pas d’une suppression de compte ni d’un blocage Auth global.

## Vérification

Tests ajoutés : actualisation sans doublon, rejet d’un événement après fermeture, échec réseau sans suspension optimiste, suspension/rétablissement confirmé, comptes protégés. Compilation Xcode et 158 tests unitaires réussis sur 2087101 (run 37658297548, zéro échec). Un run antérieur a échoué au démarrage du fichier audio de test ; la suite actuelle, incluant ce scénario, a réussi. Les tests sur deux comptes Supabase réels et appareil iPhone restent nécessaires. Aucun changement du dépôt React Native.

API Realtime vérifiée avec la version installée du SDK et sa [documentation officielle](https://supabase.com/docs/reference/swift/subscribe).
