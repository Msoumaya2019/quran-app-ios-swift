# Amis natifs — 4 octobre 2026

## Première étape
L’onglet Amis et le raccourci Accueil utilisent désormais FriendsView. Liste native avec recherche, filtres Tous/En ligne/Demandes, initiale de profil, code d’invitation partageable, ajout par code et acceptation/refus des demandes reçues. Le thème et les composants existants sont conservés. Aucune modification du dépôt React Native.

## Backend existant
FriendsLibrary réutilise friend_links, friend_profiles et les fonctions ensure_social_profile, friend_inbox, request_friend, accept_friend et decline_friend. Les contrats ont été vérifiés dans les migrations React Native existantes ; les permissions et validations serveur existantes continuent de s’appliquer. Aucune migration SQL. La présence est facultative pour les anciens déploiements et respecte share_online ; elle n’est pas présentée comme actuelle hors connexion.

## Cache et réseau
Snapshot JSON protégé et écrit atomiquement, dans Application Support/CoranNative/Friends, un fichier par UUID utilisateur. Chargement local immédiat ; réseau en arrière-plan à l’ouverture, au geste de rafraîchissement et à la reconnexion. Changement de compte : remise à zéro de l’état affiché et jeton de génération empêchant une ancienne requête de publier dans le nouveau compte. Un cache dont le propriétaire ne correspond pas au fichier demandé est rejeté. Les liens étrangers et bloqués sont exclus de la projection.

Une action sociale exige une réponse serveur, sans succès local fictif. Ces actions ne sont pas placées dans la file de progression : contrairement aux validations de lecture, une invitation peut échouer pour code inconnu, relation déjà existante ou permissions. En cas d’échec, le formulaire reste accessible pour réessayer. Aucune connexion réseau ne bloque l’ouverture de l’application.

## Vérifications
Tests ajoutés : filtrage des relations et demandes reçues, recherche sans distinction de casse/accents, respect du partage de présence, conservation du contrat JSON et isolation du cache lors du changement de compte. Parcours UI : ouverture native d’Amis et formulaire d’ajout, absence de code empêchant l’envoi. Vérification complète réussie : **94 tests unitaires + 17 tests d’interface, aucun échec**, sur iPhone 17 Pro Max simulé : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37234691574. Capture du formulaire contrôlée. Aucune archive/IPA dans cette vérification.

## Fichiers
Ajoutés : Models/FriendsSnapshot.swift, Services/FriendsLibrary.swift, Features/Friends/FriendsView.swift et Tests/FriendsTests.swift. Modifiés : App/CoranNativeApp.swift, Features/Navigation/RootView.swift, UITests/PhaseOneUITests.swift et références du projet Xcode existant.

## Suite
Cette étape ne constitue pas la migration sociale complète : photos, édition du profil et des préférences de partage, suppression/blocage, conversations, groupes, défis Quiz et notifications restent à intégrer. Les demandes entre deux comptes Supabase réels et les conditions réseau sur appareil physique restent à tester. La capture montre aussi un problème de largeur du titre de la barre commune sous le simulateur iOS actuel, à corriger dans les finitions communes. La première IPA de test (commit 8d3b703) précède Amis ; une seconde livraison est lancée pour cette étape, selon la demande de générer une IPA à chaque grand ajout.

## Profil et progression partagée
FriendDetailView est accessible depuis la carte d’un ami accepté. Les statistiques et l’objectif proviennent uniquement du RPC existant friend_overview. Le champ share_progress de friend_profiles doit être explicitement vrai avant d’afficher un résultat mis en cache. La liste est actualisée avant la requête du détail, sans bloquer l’affichage local. Les anciens caches sans ce champ ne révèlent donc pas les statistiques par défaut. Les résultats sont conservés par compte et les statistiques des liens supprimés, bloqués ou privés sont retirées à la prochaine actualisation. Un jeton de génération empêche une réponse appartenant au compte précédent d’être publiée.

Le format du cache est rétrocompatible : overviews est facultatif. Deux tests vérifient l’autorisation d’affichage et la relecture des anciens fichiers. Un parcours UI vérifie les statistiques partagées déjà synchronisées. Vérification complète réussie : **96 tests unitaires et 18 tests d’interface sans échec** : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37237846079. Livraison Amis avec parcours UI ciblé réussi et archive Release réussie : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37237972915. Capture du profil contrôlée : chiffres, objectif et barres cohérents, affichage depuis le cache.

Ajout de Features/Friends/FriendDetailView.swift et compléments dans FriendsSnapshot, FriendsLibrary, FriendsView, App et les tests. Aucune nouvelle migration SQL. IPA arm64 non signée (0.1.0, build 1) contrôlée : ZIP valide, 604 pages Médine, aucun ReaderTestFixtures. Taille 130 636 870 octets ; SHA-256 b91b7c27596a92a918faeea8a3018c6013d3dc9e6a4f9e16211b5f8821fb7363. Livraison du 5 octobre : https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-amis-2026-10-05. Les mesures et échanges entre comptes réels sur iPhone restent à effectuer.
