# Correction vocale administrateur — 7 octobre 2026

Dans Administration → Récitations à écouter → récitation, l'administrateur peut enregistrer une correction, l'arrêter, la réécouter, la supprimer ou l'envoyer avec ou sans commentaire.

## Réutilisation

Le microphone et la préécoute utilisent `VoiceRecorderService` existant. La publication passe par `ModerationLibrary` et `ModerationRepository`. Le lecteur de retours utilisateur existant affiche ensuite le commentaire et permet l'écoute, avec son cache local.

Le fichier est privé dans le bucket existant `recitations`, chemin `feedback/<admin UUID>/<request UUID>.m4a`. L'identité administrateur est contrôlée avant et après les appels réseau. Taille maximale : 50 Mio, aucun fichier vide accepté.

La fonction Supabase existante `finalize_recitation_correction` publie le retour et incrémente la révision de correction. Son identifiant de requête stable déduplique les nouvelles tentatives. Le fichier n'est pas écrasé : si l'upload a déjà abouti, son contenu est vérifié avant de reprendre la publication. Cela conserve les policies actuelles, qui autorisent insertion/lecture et ne nécessitent pas une policy d'écrasement.

Un échec conserve le texte et le brouillon tant que l'écran reste ouvert. Quitter l'écran supprime le brouillon temporaire et arrête le microphone/la préécoute. Changer de compte invalide l'état et empêche un résultat tardif d'apparaître pour le nouveau compte. La publication exige internet ; aucun faux succès local.

## Fichiers modifiés

- `Features/Friends/ModerationView.swift`
- `Services/ModerationLibrary.swift`
- `Repositories/ModerationRepository.swift`
- `App/CoranNativeApp.swift` : fixtures Debug uniquement
- `Tests/ModerationTests.swift`
- `UITests/PhaseOneUITests.swift`

## Tests

136 tests unitaires réussis sur 288029c, dont envoi vocal sans commentaire, nouvelle tentative conservant le même identifiant et rejet d'un fichier vide. Test UI d'enregistrement/envoi sans texte réussi sur simulateur iPhone 17 Pro Max (51,97 secondes).

Le correctif ultérieur de stockage respecte les policies SQL existantes. Son projet est recompilé avec succès par le test de rappels (37612642434). Le parcours de régression écoute / marquer comme écoutée / retour écrit a aussi réussi sur ce correctif (37613452942, 53,33 secondes). La publication avec le véritable compte administrateur et le microphone physique reste à vérifier ; la CI utilise un serveur de test et un fichier audio de test.

Aucune migration SQL réalisée et aucun fichier React Native modifié. Le serveur doit déjà disposer de la fonction `finalize_recitation_correction` du contrat existant ; une fonction absente ou des droits insuffisants produisent une erreur visible, sans annoncer l'envoi comme réussi. La notification distante dépend encore du raccordement APNs.
