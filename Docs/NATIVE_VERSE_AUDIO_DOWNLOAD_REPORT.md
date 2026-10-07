# Actions des versets, audio et téléchargements — 7 octobre 2026

## Intégration

Le lecteur UIKit/SwiftUI, ses images, ses coordonnées et son moteur AVFoundation sont conservés. L’appui long utilise les coordonnées existantes dans le rectangle aspectFit de la page. Il ouvre une sheet native sans déplacer ni sélectionner durablement le texte. Les actions utilisent le récitateur courant, les marque-pages, la progression et la file de synchronisation existants.

La traduction française et le texte pour copier/partager proviennent des ressources déjà présentes dans React Native, copiées en lecture seule. Les 6 236 références des deux fichiers ont été vérifiées. Elles ne servent pas à reconstruire le Mushaf.

## Persistance

- Difficulté : opération `difficulty` existante, copie locale et synchronisation du même état partagé.
- Appris : `knowledge`, `memorizedAt`, `studyProgress`, consolidations J+1/J+3/J+7 et révisions existants. Une validation individuelle ne valide pas toute une séance programmée.
- Prochaine révision : extension JSON `nativeManualReviewDue` dans l’état utilisateur existant, indépendante de la difficulté. La file prioritaire commune la lit ; une validation la consomme sans supprimer une demande plus récente.
- `nativeVerseActionAt` rend le rejeu des opérations idempotent. Aucune nouvelle table ni migration Supabase.

## Audio immédiat

Le bouton « Réglages » est l’entrée de la sheet. La répétition affichée dans le mini-player n’est plus un bouton. Chaque changement enregistre les préférences existantes et configure le même lecteur : vitesse sans relancer le verset, compte et comportement de fin au prochain événement, pauses à la prochaine transition, passage via la file existante. « Fermer » ferme seulement la sheet.

Un seul Stepper règle les répétitions ; zéro conserve la répétition infinie déjà disponible. Vitesse : 0,75 / 0,85 / 1 / 1,15 / 1,25. Fin : arrêter, verset suivant, continuer. Pause pour réciter : désactivée / 3 / 5 / 10 / 15 secondes. Si deux pauses sont demandées, le silence utilise leur maximum. Les transitions asynchrones sont protégées contre les changements rapides de passage et de vitesse.

## Téléchargement

Le service d’installation existant utilise un `URLSessionDownloadTask`. Le pourcentage est `totalBytesWritten / totalBytesExpectedToWrite` ; si la taille est inconnue, l’indicateur reste indéterminé. Les notifications d’interface sont limitées à dix par seconde et la valeur finale utilise les compteurs natifs.

Un seul téléchargement de la source est autorisé. Il continue pendant la navigation dans l’application. Le ZIP seul ne marque pas la source installée : extraction, contrôle CRC de toutes les images et marqueur atomique restent nécessaires. Les erreurs permettent de réessayer. L’ancienne source reste affichée jusqu’à ce que la nouvelle soit prête.

Limite : pas de reprise automatique après fermeture forcée de l’application ni de session de téléchargement OS en arrière-plan persistante dans cette étape.

## Fichiers

Nouveaux : `Features/Quran/VerseActionsSheet.swift`, `Core/VerseStudyChange.swift`, `Services/QuranDownloadTransfer.swift`, `Components/QuranDownloadProgress.swift`, deux JSON dans Resources, `Tests/VerseStudyTests.swift`, `Tests/QuranDownloadTests.swift` et ce rapport.

Modifiés : `App/AppStore.swift`, `Models/ReaderOperation.swift`, `Core/AudioRepeat.swift`, les projections/validations de révision, `Services/QuranAudioService.swift`, `Services/QuranResourceService.swift`, `Features/Quran/QuranPager.swift`, `Features/Quran/QuranReaderView.swift`, `Features/Reports/ProblemReportSheet.swift`, `Components/AudioRepeatSheet.swift`, `Components/QuranMiniPlayer.swift`, générateur/projet Xcode, tests audio et UI du lecteur.

## Validation

126 tests unitaires réussis sur GitHub macOS pour la version finale du produit (`6e82c5b`), incluant le téléchargement réel du ZIP et le changement de passage pendant une pause de répétition : [exécution Xcode](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37600495851).

28 parcours UI (15 généraux et 13 du lecteur) et archive iPhone réussis sur `94bd993` : [exécution complète](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37599694556). Cela inclut vingt pages sur les deux sources, les modes de séance, l’appui long, la traduction, les actions de progression, les marque-pages, la difficulté et le suivi audio. La seule modification produit ultérieure conserve le choix de répétition infinie dans le Stepper. Un parcours ciblé vérifie ce contrôle sur la version finale.

Un premier test audio a échoué sur le démarrage à froid du codec du simulateur ; le délai de disponibilité initial a été adapté. Deux vérifications UI ont échoué sur l’identifiant puis la géométrie d’accessibilité du Stepper natif. Le test vérifie désormais les appuis, la valeur obtenue et la lecture effective. La capture confirme le contrôle visible et le compteur à trois. Le [rejeu final et l’archive](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37602547752) ont réussi sur `e6b3b5d`. Aucun résultat de mesure Instruments sur appareil réel n’est revendiqué.

## Livraison

[IPA Lecteur et audio](https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-lecteur-audio-2026-10-07), arm64 non signée, 131 803 528 octets. SHA-256 vérifié localement et comparé au digest GitHub : `9d29f5384f0ef050ded21842f7931fd9d04ed294a2c2521e70343336c8ddc158`. Les 604 pages Médine sont incluses ; Coran 1441 reste téléchargé à la sélection. Aucun asset de test du simulateur dans l’archive.
