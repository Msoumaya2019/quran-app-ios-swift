# Administration : récitations et messages — 5 octobre 2026

## Accès

Réglages → Administration → Récitations à écouter / Modération des messages. Les entrées sont réservées aux comptes app_admins, comme l’administration Quiz existante. Chaque requête et action vérifie de nouveau la session et l’appartenance à app_admins. Les RLS restent l’autorité côté serveur. Aucune clé privilégiée ajoutée dans l’application.

## Récitations

Liste paginée de 50 enregistrements, avec auteur, date, type (Coran/invocation) et statut d’écoute. La sélection ouvre un lecteur AVAudioPlayer utilisant le service de réécoute existant. Un seul fichier est chargé à la demande depuis le bucket privé recitations, sans URL publique ni copie persistante des enregistrements d’autres utilisateurs. La lecture s’arrête à la sortie et au changement de compte. Les chemins doivent correspondre au propriétaire et au véritable enregistrement serveur ; chemins traversants, vides et fichiers de plus de 50 Mio sont refusés.

Action explicite « Marquer comme écoutée », confirmée via listened_at. Le retour écrit est stocké dans recitation_feedback avec admin_id et recitation_id, comme dans React Native. Un UUID est conservé pour réessayer un même retour après perte de confirmation ; le contenu confirmé doit correspondre. Aucun commentaire religieux généré automatiquement. Les récitations associées aux messages sont également accessibles à l’écoute.

## Messages

Liste paginée des conversations privées et groupes, auteur, date et contenu intégral dans le détail. La suppression demande confirmation, appelle delete_friend_message et n’affiche « Message supprimé » qu’après relecture de deleted_at. Il s’agit de la suppression logique existante, pas d’un effacement d’historique.

Sous-écran Signalements de messages : raison, extrait, statut et action « Marquer comme traité », via resolve_friend_report. Cette action traite le signalement et ne supprime pas automatiquement le message. Les messages peuvent être supprimés depuis leur liste dédiée.

## Données et fichiers

Aucune migration SQL. Tables existantes : app_admins, recitations, recitation_feedback, friend_messages, friend_message_reports et friend_profiles. Bucket privé : recitations. RPC existants : delete_friend_message et resolve_friend_report.

Ajouts : Repositories/ModerationRepository.swift, Services/ModerationLibrary.swift, Features/Friends/ModerationView.swift et Tests/ModerationTests.swift. Modifications : App, SettingsView, RecitationPlaybackService, QuizLibrary (fixture DEBUG uniquement), PhaseOneUITests et références du projet Xcode existant. Le dépôt React Native reste intact.

## Vérifications

Tests unitaires : absence de suppression locale avant confirmation, rejet d’une réponse après changement de compte, purge des contenus après refus d’accès, conservation de l’UUID d’un retour réessayé et validation du chemin audio privé. Tests UI : écoute/arrêt d’un fichier local, statut écouté, retour écrit et suppression confirmée d’un message. Les fixtures techniques sont limitées au DEBUG ; aucune donnée réelle n’est créée dans Supabase par ces tests.

Validation unitaire : 120 tests sans échec, dont 5 nouveaux tests de modération, sur le commit ec499a22c79eb16e09473b3d4feb094d5954fc07 (run 37297727596). La suite UI a validé 14 des 15 parcours sur d037969 (run 37299710576), dont écoute et retour écrit. Le dernier parcours ciblait incorrectement le bouton situé derrière la confirmation iOS ; correction du test uniquement, puis suppression confirmée réussie (1 test, 0 échec, run 37592568192). Total : 15 parcours UI distincts vérifiés, sans modification produit entre ces vérifications.

Archive iPhone Release réussie le 7 octobre 2026 sur e9530969f01f6b76d4badd8a8762be95ef65b759, run 37592568192. IPA non signée, à signer avant installation. Captures simulateur iPhone 17 Pro Max contrôlées. Cette version conserve le téléchargement à la demande du Coran 1441.

IPA : [Administration — 7 octobre 2026](https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-moderation-2026-10-07). Contrôle local : archive intacte, arm64, 604 pages de Médine, absence des fixtures DEBUG, 131027354 octets. SHA-256 : `5bc30ce88e05446845eff3f0c0b7a451789c1cfe6834dd173f9757b25f6fca1c`.

## Limites

La modération nécessite internet et ne place pas d’actions administrateur dans la file hors connexion. Pas de suspension d’utilisateurs ni de correction vocale dans ce complément. La correction écrite utilise le contrat existant ; son affichage côté utilisateur React Native est déjà disponible, tandis que l’écran natif de réception des retours reste à migrer. Les accès et fichiers réels devront être vérifiés avec un compte administrateur sur iPhone ; les tests simulateur ne certifient pas l’état des policies déployées.
