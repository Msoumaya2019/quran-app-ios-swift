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
Cette étape ne constitue pas la migration sociale complète : photos, détail/progression des amis, édition du profil et des préférences de partage, suppression/blocage, conversations, groupes, défis Quiz et notifications restent à intégrer. Les demandes entre deux comptes Supabase réels et les conditions réseau sur appareil physique restent à tester. La capture montre aussi un problème de largeur du titre de la barre commune sous le simulateur iOS actuel, à corriger dans les finitions communes. L’IPA de test demandée est générée séparément depuis le commit 8d3b703, avant cette étape Amis, afin de livrer le lecteur et les révisions déjà vérifiés.
