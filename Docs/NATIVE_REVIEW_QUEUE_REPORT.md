# Révisions récentes et prioritaires natives

## État précédent
Le lecteur, les cycles, les validations habituelles, les difficultés personnelles/administrateur et les consolidations explicites étaient déjà intégrés. Cette étape complète le programme Swift existant ; aucun projet ni dépôt recréé, aucun fichier React Native modifié.

## File commune
ReviewQueueProjection rassemble les validations partielles à reprendre, les révisions récentes (prochaine étape J+1/J+3/J+7 arrivée à échéance), les versets difficiles à échéance et la part habituelle du cycle. L’ordre reprend celui du lecteur React Native. Un passage n’est inclus qu’une fois dans la file ; les trous et changements de sourate créent des fragments distincts. Les parties inconnues et déjà révisées le jour local sont exclues. Les dates prévues ne sont pas remplacées par la date de reprise.

Accueil utilise maintenant cette même file pour son accès Révision. Programme affiche les catégories récente et prioritaire et conserve la section de consolidation permettant les validations anticipées. Le même QuranReaderView, le même header, les annotations en marge, l’audio et l’écran de validation servent à toutes les catégories.

## Validation et chevauchement
RevisionValidation garde sa compatibilité Codable avec les anciennes opérations. La catégorie optionnelle distingue habitual / priority / recent ; les anciennes opérations sans catégorie suivent le moteur habituel existant. Les révisions récentes et prioritaires peuvent être validées sans cycle habituel. Elles enregistrent la catégorie dans reviewHistory et studyProgress, avec scheduledDate indépendante de completedAt.

La validation ne crédite que les versets nouveaux, les autres étant dédoublonnés par jour. Quand les mêmes versets appartiennent à la part du cycle assignée ce jour et à une consolidation à échéance, la validation crédite ces mécanismes également. Les validations récentes peuvent être anticipées sans déplacer l’échéance ; les étapes suivantes restent ancrées à learnedAt. Chaque étape créditée garde un événement de consolidation déterministe dans consolidationHistory.

Les appréciations conservent les marqueurs persistants : bien maîtrisé reporte l’échéance sans enlever Difficile ; hésitant programme J+2 ; à retravailler J+1. Les marqueurs administrateur et champs inconnus sont conservés. Un retrait volontaire, une nouvelle échéance prioritaire ou un nouvel apprentissage rendent une ancienne opération inapplicable. Les dates de marquage natives et l’historique empêchent une validation plus ancienne d’écraser un changement plus récent dans ce moteur complémentaire.

## Anciens comptes
ConsolidationRecovery remplit les fiches manquantes et les dates J+1/J+3/J+7 manquantes à partir de memorizedAt. Une étape n’est récupérée comme terminée que si une véritable révision à une date appropriée est dans reviewHistory ; une même journée ne permet pas de remplir plusieurs étapes. Aucune échéance passée n’est considérée comme validée automatiquement. Les dates et validations des fiches existantes sont conservées ; un réapprentissage repart de sa nouvelle date. Cette récupération est effectuée dans RevisionScheduleChange et utilise donc la file locale et le recalcul sur le dernier JSON distant.

## Stockage
Aucune table, colonne ou migration SQL supplémentaire. ReaderOperation.revision et reviewSchedule, LocalStorageService et le mécanisme Supabase compare-and-swap existants sont réutilisés. Les données restent compatibles avec le format React Native. Les essais croisés sur un compte réel et la signature Apple restent à effectuer.

## Tests
Tests unitaires : ordre/dédoublonnage, exclusion des inconnus, dates réelles d’échéance, chevauchement du cycle, appréciations et persistance du statut difficile, révisions sans cycle, validation partielle et reprise, retrait volontaire, nouvelle échéance et réapprentissage, pause/futur/déjà fait, validation anticipée, sérialisation/rejeu. Récupération historique : dates distinctes, aucun checkpoint inventé, fiches existantes immuables et réapprentissage.

Tests UI hors ligne : ouverture et validation partielle des deux catégories dans le lecteur existant, centrage conservé et repères en marge. Vérification complète : 91 tests unitaires et 15 parcours UI réussis, dont les deux nouvelles catégories : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37231063308. Le dernier test UI audio échouait car le geste normalisé XCTest plaçait le curseur à 14 secondes au lieu de 30 (capture conservée). Le test fait désormais glisser le pouce du curseur jusqu’au milieu mesuré et conserve sa vérification 26–34 secondes ; aucune modification du code produit pour ce correctif de test. Son rejeu ciblé a réussi : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37232810658. Soit 107 tests distincts vérifiés entre la série complète et le rejeu. Captures des validations récentes/prioritaires et du seek/surlignage audio vérifiées. Archive/IPA ignorées dans les deux workflows, conformément à la demande utilisateur.

## Fichiers
Ajoutés : Core/ReviewQueueProjection.swift, Core/RevisionSupplementalValidation.swift, Core/ConsolidationRecovery.swift, Tests/ReviewQueueTests.swift, Tests/ConsolidationRecoveryTests.swift.
Modifiés : Core/ProgramProjection.swift, Core/HomeProjection.swift, Core/RevisionValidation.swift, Core/RevisionSchedule.swift, Features/Program/ProgramView.swift, App/CoranNativeApp.swift (fixtures DEBUG), Tests/RevisionValidationTests.swift, UITests/ReaderUITests.swift et projet Xcode.

## Limites
Les cartes du Programme peuvent répéter la présentation du premier passage dans Aujourd’hui et sa catégorie, comme les raccourcis existants ; la file effective dédoublonne les versets. Le cycle habituel continue à présenter son prochain groupe contigu, et les groupes suivants deviennent visibles au fur et à mesure de la validation. Le moteur habituel existant reste distinct pour sa gestion des cycles archivés. Les listes « tous les versets à retravailler » sans échéance, la messagerie, le Quiz natif et les notifications avancées restent à migrer.
