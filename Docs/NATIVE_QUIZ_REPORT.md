# Quiz natif et Progrès — 5 octobre 2026

## Réutilisation
Application Swift existante, client Supabase partagé, cinq onglets conservés. Le dépôt React Native est consulté pour ses contrats et n’est pas modifié. Aucune migration SQL ni modification des permissions serveur.

## Fonctionnalités
- Accueil > Quiz : Question du jour, historique et défis entre amis.
- Réponse quotidienne immuable par date locale. Une réponse déjà donnée sur l’autre application prend priorité après synchronisation.
- Questions téléchargées lisibles hors connexion ; réponse locale durable par utilisateur. La correction n’est jamais inventée ou embarquée avec la question publique.
- Défis de 5 ou 10 questions, sélection d’un ami accepté et quiz thématique facultatif. Questions figées par le serveur à la création, délai 48 heures et scores/corrections seulement après validation des deux joueurs. Un défi expiré n’attribue aucune victoire.
- Administration dans Réglages, visible après vérification de l’appartenance à app_admins : création, modification, duplication, désactivation et suppression de questions ; constitution de thèmes de exactement 10 questions actives. Source obligatoire. Les RPC vérifient eux-mêmes les droits administrateur.
- Écran Progrès : versets réellement connus sur 6236, pages entièrement connues, Juz’ entièrement connus, objectif, semaine, régularité et statistiques Quiz confirmées. Aucun chiffre d’exemple des maquettes n’est présenté comme donnée réelle.

## Hors ligne et sécurité
Cache JSON dans Application Support/CoranNative/Quiz, un fichier par UUID, écriture atomique et protection iOS jusqu’au premier déverrouillage. Changement de compte : suppression de l’état publié et jeton empêchant une ancienne requête de publier sa réponse dans le nouveau compte. Les réponses en attente restent enregistrées tant que quiz_snapshot n’a pas confirmé le jour correspondant. quiz_answer_daily est idempotent par utilisateur/jour, y compris après perte de confirmation ou réponse concurrente depuis React Native. Reprise au lancement, ouverture du Quiz, retour au premier plan et reconnexion.

Défis : lecture des données synchronisées hors ligne, action réseau obligatoire pour créer ou répondre. Administration : aucune réponse contenant des solutions administrateur n’est écrite dans le cache disque public du Quiz.

## Services existants
quiz_snapshot, quiz_answer_daily, quiz_create_challenge, quiz_answer_challenge, quiz_admin_list, quiz_admin_save, quiz_admin_delete, quiz_admin_sets, quiz_admin_save_set, quiz_admin_delete_set. Tables quiz_* et app_admins existantes. Aucune clé privilégiée.

## Vérification
Tests ajoutés : unicité quotidienne, mauvais choix et mauvaise date refusés, relecture de réponse hors ligne sans correction inventée, priorité de réponse serveur, confidentialité des scores avant achèvement, absence de victoire pour les défis expirés, statistiques confirmées et objectif sans double comptage. Parcours UI : ouverture sans réseau et sans sixième onglet, réponse locale bloquée après réouverture. Vérification Xcode complète et nouvelle IPA en cours ; les résultats seront consignés après confirmation.

## Limites restantes
Échanges de défis et administration à vérifier avec deux comptes Supabase réels et un compte administrateur. Les notifications APNs et l’administration complète des autres contenus ne sont pas encore migrées. Historique Quiz téléchargé en bloc suivant le contrat existant. Création de défi sans clé d’idempotence serveur : une confirmation réseau perdue nécessite une actualisation avant de relancer une création. Le chronomètre d’expiration est contrôlé par le serveur et actualisé à l’ouverture/rafraîchissement.

## Fichiers
Models/QuizCache.swift, Models/QuizChallengeProjection.swift, Services/QuizLibrary.swift, Features/Quiz/QuizView.swift, Features/Quiz/QuizChallengesView.swift, Features/Quiz/QuizAdminView.swift, Core/ProgressProjection.swift, Features/Progress/NativeProgressView.swift, Tests/QuizTests.swift, Tests/ProgressTests.swift. Intégration dans App, Accueil, navigation, Réglages, profil d’ami et tests d’interface ; références Xcode régénérées.
