# Audio et confidentialité — 5 octobre 2026

## Audio

QuranAudioService observe désormais la durée du fichier en plus de l’état du lecteur. Apple précise qu’une durée peut rester indéfinie lors de l’initialisation et être publiée ensuite : https://developer.apple.com/documentation/avfoundation/avplayeritem/duration.

Une valeur transitoire indéfinie n’efface plus une durée connue. Les changements de verset/réciteur continuent de remettre explicitement la timeline à zéro. Lors d’un seek, les mises à jour périodiques sont suspendues jusqu’à sa confirmation ; un identifiant propre à l’opération et la vérification du player empêchent une ancienne confirmation de modifier le nouveau verset. Les observations sont invalidées lors du remplacement du lecteur.

Les fichiers audio, récitateurs, répétitions et coordonnées du Mushaf sont conservés. Ce correctif traite des risques identifiés dans le code ; le résultat du test de déplacement tactile doit être vérifié séparément.

## Profil ami

Réglages → Profil ami et confidentialité permet de modifier le nom affiché (2 à 40 caractères), share_online et share_progress. Les champs proviennent du cache existant et aucun consentement n’est activé par défaut. L’enregistrement est direct, nécessite une confirmation serveur et conserve le formulaire en cas d’échec.

Utilisation de ensure_social_profile et mise à jour ciblée de friend_profiles pour le compte authentifié. Avatar, localisation et autres champs restent conservés. Avant une mutation sociale, le compte Supabase doit correspondre au propriétaire du cache ; les réponses d’un compte précédent ne sont pas publiées. Aucune nouvelle table, policy ou migration SQL.

## Fichiers et tests

Ajout : Features/Friends/SocialProfileSettingsView.swift. Modifications : SettingsView, FriendsLibrary, QuranAudioService, FriendsTests, PhaseOneUITests et références Xcode existantes.

Le test unitaire ajouté vérifie qu’un enregistrement sans réseau n’altère pas le profil local et n’annonce pas de succès. Un parcours UI vérifie le formulaire, le nom conservé après l’échec et l’absence de confirmation fictive. Les tests AVFoundation existants couvrent seek/pause/reprise, changement de réciteur, fin de verset et répétitions.

Validation unitaire : 8 tests AVFoundation ciblés sans échec (run 37292735488), puis 115 tests unitaires sans échec sur le commit f79bfe8 (run 37293125973). Le parcours UI de confidentialité réussit (run 37293131156), sur iPhone 17 Pro Max simulé. Capture contrôlée : nom conservé, deux consentements désactivés et message de connexion nécessaire.

Le premier rejeu UI audio après correction n’a pas lancé l’application : délai Xcode dépassé (run 37292739642). La préparation explicite du simulateur et la désactivation des clones parallèles pour les parcours UI ciblés sont ajoutées au workflow. Le rejeu 37294484788 réussit : déplacement vers le milieu du verset, passage suivant/précédent, réduction du player et centrage du Mushaf. Aucune assertion ni geste du test n’a été affaibli. Ces résultats couvrent le simulateur, pas encore l’appareil réel.

Aucune archive demandée pour ces petits compléments. L’IPA Groupes précédemment publiée ne contient pas ces modifications.

## Limites

La modification de l’avatar, le heartbeat de présence native et les notifications APNs restent à migrer. Les préférences de partage doivent encore être vérifiées entre deux comptes réels. Le dépôt React Native n’est pas modifié.
