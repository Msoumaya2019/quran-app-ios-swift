# Corrections de récitation par verset — 7 octobre 2026

Complément de la modération native existante : dans une récitation du Coran, activer « Corriger un verset précis », sélectionner le verset avec le contrôle −/+, puis envoyer un commentaire et/ou l'enregistrement vocal existant. Le libellé indique le nom de sourate et son numéro local de verset, y compris si la récitation traverse plusieurs sourates.

La sélection est limitée au passage enregistré. Elle n'est pas proposée pour les invocations. Une plage invalide ou un verset extérieur est rejeté avant tout envoi ; le repository vérifie aussi la plage actuelle côté serveur avant le téléversement, puis la fonction SQL contrôle à nouveau les bornes.

## Contrat partagé

La publication utilise la fonction existante `finalize_recitation_correction`, avec `p_verses = [{verseId, comment}]`, un commentaire général vide et un chemin vocal facultatif. L'argument `p_voice_path` est explicitement encodé à null pour une correction écrite seule. La table reste `recitation_corrections` ; aucun nouveau schéma ni nouveau système de progression.

Les fichiers, permissions administrateur et nouvelles tentatives utilisent le mécanisme vocal existant. Modifier le verset ou le type de retour crée une nouvelle identité d'envoi ; réessayer le même retour conserve son identité. Aucun succès n'est affiché après un changement de compte. Le commentaire et le brouillon restent dans l'écran en cas d'échec.

L'utilisateur reçoit la référence exacte et l'observation dans « Mes récitations → Retours et corrections ». Le serveur peut également créer une ligne générale vide pour la pièce vocale : cette ligne redondante est masquée lorsque le même fichier est déjà associé à une correction de verset. Les retours généraux substantiels, les autres fichiers et les données serveur restent conservés. Le cache existant garde la correction et son audio après téléchargement.

## Audio

La lecture de la récitation est désactivée pendant la capture, la demande de permission microphone et la préécoute d'une correction, pour éviter deux usages simultanés de la session audio. Les commandes de sélection et suppression restent désactivées pendant un envoi.

## Fichiers modifiés

- `Features/Friends/ModerationView.swift` : sélection du verset, contrôles audio et identité d'envoi.
- `Services/ModerationLibrary.swift` : validation et routage vers le retour général ou précis.
- `Repositories/ModerationRepository.swift` : publication partagée et vérification du passage serveur.
- `Models/Recitation.swift`, `Repositories/RecitationRepository.swift` : fusion d'affichage sans pièce vocale redondante.
- `App/CoranNativeApp.swift`, `Tests/ModerationTests.swift`, `UITests/PhaseOneUITests.swift` : données techniques Debug et vérifications.

## Vérification

Projet Xcode généré validé et `git diff --check` réussi. Sur ef7740d : **140 tests unitaires sans échec** (37616328748, 41,12 secondes), parcours iPhone de sélection/envoi d'une correction précise réussi (37616333523, 71,37 secondes), régression de l'enregistrement/envoi vocal général réussie (37616338148). Compilation Xcode réussie. Capture iPhone 17 Pro Max inspectée : référence « Al Fâtiha · verset 2 », sélection bornée et commandes visibles. Ces parcours utilisent les fixtures Debug ; aucune correction réelle n'est publiée dans Supabase par la CI.

Les tests couvrent les bornes du passage, le rejet des invocations, la conservation de l'identité en cas de nouvelle tentative, un changement de compte pendant l'envoi et la conservation des retours généraux utiles lors de la fusion.

Aucune migration Supabase effectuée et aucun fichier React Native modifié. La fonction et les policies déployées doivent être vérifiées avec le compte administrateur réel ; les tests utilisent des données techniques. Aucune nouvelle IPA générée pour ce complément.
