# Validation du lecteur natif — 7 octobre 2026

## Modifications conservées

- `QuranPageCache` invalide les anciennes préparations lorsqu’une autre fenêtre page/source est demandée, ou lors de sa purge. Une préparation dépassée ne poursuit plus le chargement de ses voisines.
- Le coordinateur UIKit vérifie son contexte avant de modifier la fenêtre du cache, puis avant chaque décodage.
- La fenêtre conservée reste la page actuelle et ses voisines, au maximum trois images décodées.
- Les gestes de page et de retour iOS existants sont conservés. La tentative de modification des gestes système a été retirée : le parcours réussit avec le comportement d’origine.
- Les images, coordonnées des versets, pagination, audio et données utilisateur sont inchangés. Aucune migration Supabase et aucune modification du dépôt React Native.

## Tests et compilation

| Contrôle | Résultat | Run GitHub |
|---|---|---|
| Suite unitaire, dont préparations concurrentes et vingt pages locales par source | 164 tests réussis, aucun échec | 37671462011 |
| Médine : vingt swipes en avant, cinq en arrière, cinq en avant | Réussi | 37677768137 |
| 1441 : même parcours avec images originales locales | Réussi | 37677768137 |
| Activation d’un rappel puis fermeture/réouverture des réglages | Réussi | 37673341894 |

Le code de production compilé pour les 164 tests (aeabaff) est identique à celui du dernier parcours UI réussi (43e24b6) ; les différences concernent les tests. Les deux tests UI ont vérifié les images réellement prêtes et visibles, l’absence d’erreur de page, et la stabilité du cadre d’affichage. Les captures finales de la page 21 ont été inspectées pour chaque source sur le simulateur iPhone 17 Pro Max.

Les premiers essais utilisaient un glissement lent à mi-largeur, qui n’a pas permis de valider le changement de page. Le contrôle utilise désormais `swipeRight/swipeLeft(velocity: .fast)` sur la page visible. Aucune correction de conflit de gestes n’est revendiquée ni conservée sans nécessité.

Le test des rappels fait défiler le formulaire jusqu’à ce que tout l’interrupteur soit dans la zone visible avant de le toucher. Les options partagées ont allongé le formulaire ; un interrupteur partiellement visible peut être déclaré touchable par XCTest alors que le point choisi est hors écran.

## Mesures et limites

Après les parcours unitaires : trois pages conservées ; 71 562 240 octets décodés pour Médine et 40 089 600 pour 1441 (run 37669624024). Les décodages observés étaient de 41–73 ms pour Médine et de 78–145 ms pour 1441 sur ce runner.

`decodedBytes` mesure les images du cache, pas la mémoire totale du processus ni les buffers internes de UIKit. Les signposts de décodage restent disponibles pour Instruments. Les mesures CPU, pics mémoire et fluidité sur un iPhone physique restent nécessaires ; les tests GitHub ne les remplacent pas.

Un premier run unitaire a signalé un échec du passage automatique au verset suivant ; la suite complète de 164 tests a ensuite réussi sans modification du moteur audio.

Aucune nouvelle archive IPA pour cette vérification intermédiaire. Le dernier IPA publié contient le correctif page/rubu‘ ; il précède les protections de préchargement décrites ici.

## Fichiers

- Modifiés : `Services/QuranPageCache.swift`, `Features/Quran/QuranPager.swift`, `Features/Quran/QuranReaderView.swift` (identifiant accessible de choix de source), `Tests/ReaderTests.swift`, `UITests/PhaseOneUITests.swift`, `CoranNative.xcodeproj/project.pbxproj`.
- Créé : `UITests/ReaderPagingUITests.swift` et ce rapport.
