# Retours de récitation — 7 octobre 2026

## Fonctionnement

Dans Plus → Mes récitations, « Retours et corrections » ouvre les observations générales et corrections par verset reçues depuis l’administration. Une correction vocale peut être écoutée avec le service de lecture des récitations existant. La fermeture de l’écran arrête cette lecture et empêche un téléchargement tardif de la relancer.

Les retours sont lus depuis les tables existantes `recitation_feedback` et `recitation_corrections`. Les fichiers vocaux restent dans le bucket privé `recitations`. Avant téléchargement, le repository vérifie le propriétaire de la récitation et confirme en base l’association de la correction à son fichier. Aucune modification SQL et aucun changement React Native.

## Hors connexion et comptes

La bibliothèque existante conserve un `feedback.json` par compte, à côté de son index de récitations. Les textes déjà consultés sont immédiatement disponibles. Les fichiers vocaux déjà écoutés sont conservés dans le même dossier privé. Une nouvelle version du fichier vocal invalide l’ancien cache. Un retour supprimé ou une nouvelle liste reçue ne peut pas accéder à une ancienne entrée supprimée.

Les générations de compte protègent les réponses réseau tardives. Aucun retour de l’ancien compte n’est publié après un changement de session. Les requêtes simultanées d’une même récitation sont dédoublonnées.

## Fichiers modifiés

`Models/Recitation.swift`, `Repositories/RecitationRepository.swift`, `Storage/RecitationStorage.swift`, `Services/RecitationLibrary.swift`, `Features/Quran/RecitationsView.swift`, `App/CoranNativeApp.swift` (fixture Debug seulement), `Tests/RecitationTests.swift` et `UITests/PhaseOneUITests.swift`.

## Vérification

Trois tests ajoutés et réussis : réouverture hors connexion avec texte et voix, isolation/changement de compte pendant une réponse tardive, invalidation d’un ancien fichier vocal. La [série de 130 tests unitaires](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37606348848) a réussi. Le [parcours UI](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37606353614) de lecture d’une observation par verset, écoute, fermeture et réouverture a réussi. Une erreur de compilation sur un nom de variable dans `catch` a été corrigée avant le rejeu. Cette fonctionnalité est incluse dans l’[IPA Préparation 1441](https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-preparation1441-2026-10-07), non signée.

Limites : cet écran affiche les corrections existantes ; il ne publie pas de nouvelles corrections vocales depuis l’administration et ne marque pas une correction comme traitée. Les notifications distantes APNs restent une étape distincte.
