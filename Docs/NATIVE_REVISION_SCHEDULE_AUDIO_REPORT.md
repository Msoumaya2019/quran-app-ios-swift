# Cycles de révision natifs et suivi audio

## État initial
Le lecteur natif, ses deux sources, les repères de séance, les difficultés, les validations partielles de révision, les consolidations J+1/J+3/J+7 et l’édition du programme d’apprentissage étaient déjà présents. La révision lisait uniquement les cycles existants dans Supabase. Le moteur audio changeait de verset, mais aucun calque ne représentait ce verset sur la page.

## Révisions
Core/RevisionSchedule.swift centralise la création, l’affectation quotidienne, l’archivage et la rotation des cycles. Il reprend les divisions et pondérations présentes dans les ressources natives, elles-mêmes issues du projet React Native : Juz’, Hizb, rubu‘ et poids du texte arabe par verset rapporté à sa page.

Choix disponibles dans Réglages → Modifier mes révisions :

- Cycle de 7, 14, 21 ou 30 jours.
- 1 Nisf, 1 Hizb, 1 Juz’ ou 2 Juz’ par jour.
- Pause et reprise des révisions.

Les réglages s’enregistrent directement. Les divisions incomplètement connues ne programment que les versets marqués perfect/review : aucun trou inconnu n’est ajouté. Comme dans React Native, les unités entièrement inconnues sont ignorées et les unités connues sont regroupées par deux pour le rythme 2 Juz’.

Le corpus reste un instantané pendant le cycle. Les nouveaux apprentissages ne l’élargissent pas en cours de route. Ils deviennent éligibles dans le cycle suivant après J+7, avec vérification de la date learnedAt. Les connaissances anciennes au démarrage du modèle suivent la règle de compatibilité React Native.

Une journée manquée conserve la date startDate + index du lot original. Une seule part en retard est affectée par jour, sans rassembler tous les jours manqués. Un cycle entièrement terminé reste actif jusqu’à la fin théorique de sa période ; ensuite son JSON est conservé dans reviewCycleHistory et le cycle suivant est créé. Un changement explicite de rythme archive également le précédent. Les réglages en pause ne génèrent pas de nouvelle affectation.

AppStore prépare le cycle à partir du cache avant l’attente réseau et après réception d’un état distant. La préparation et les réglages passent par l’opération reviewSchedule dans la file readerOperations existante. Le serveur reçoit une mutation recalculée sur son dernier état par le mécanisme compare-and-swap existant. Le champ JSON nativeReviewSettingsUpdatedAt protège contre le rejeu d’anciens réglages natifs. Les champs inconnus des réglages et l’historique restent conservés. Aucun SQL, aucune colonne ni table supplémentaire, aucun fichier React Native modifié.

## Surlignage audio
Components/QuranAudioOverlay.swift est un calque UIKit distinct des repères de programme. Il utilise les bounding boxes déjà présentes pour les pages originales de Médine et de Coran 1441. Seuls les fragments du verset actuellement récité reçoivent une teinte de l’accent à 12 %, sans bordure. Les autres versets et les images restent inchangés.

Le calque utilise exactement le rectangle aspectFit de l’image. Il n’ajoute aucun padding, ne change aucune contrainte ni taille de page et laisse passer les gestes. Le changement de verset actualise uniquement les annotations ; la timeline observée par le mini-player ne provoque pas de redécodage du Mushaf à chaque tick.

Le repère audio suit la lecture, les boutons précédent/suivant et le passage automatique à l’ayah suivante. Il reste visible en pause pour garder le point de reprise. Quand le verset change, la page correspondante est ouverte si la préférence reader.followAudio n’est pas false. Une page ne contenant pas ce verset n’affiche aucun surlignage audio. Les passages de programme conservent uniquement leurs repères en marge ; ils ne reçoivent aucun fond de programme.

## Tests
Ajouts : partitions temporelles et divisions exactes, quatre quantités avec trous inconnus, journées manquées, dates prévues, rotation uniquement en fin de cycle, historique, consolidation J+7 et corpus stable, pause/reprise, ordre des réglages, persistance disque et rejeu de la file, dates locales Europe/Paris en changement d’heure. Tests de géométrie du calque audio et de conservation de l’image/centrage, passage automatique au verset suivant, scénario UI de réglages hors ligne et suivi audio précédent/suivant.

Vérification Xcode réussie : 75 tests unitaires et 13 tests d’interface, soit 88 sans échec, sur simulateur iPhone 17 Pro Max. Archive Release et IPA non signée générées : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37223089109.

## Limites et suite
Les files de révisions prioritaires/récentes complètes restent à migrer ; les difficultés et la consolidation gardent leurs interfaces existantes. Les tests de synchronisation croisée sur un véritable compte React Native/Swift, la signature Apple et les mesures Instruments sur appareil physique restent à effectuer. Le champ d’ordre des réglages est natif ; les conflits simultanés avec une édition React Native nécessitent encore un essai sur compte réel. Les répétitions et plages audio font l’objet du complément décrit ci-dessous.

## Fichiers
Ajouts : Core/RevisionSchedule.swift, Features/Settings/RevisionSettingsView.swift, Components/QuranAudioOverlay.swift, Tests/RevisionScheduleTests.swift et Tests/QuranAudioOverlayTests.swift.

Modifications : App/AppStore.swift, Models/ReaderOperation.swift, Features/Settings/SettingsView.swift, Features/Program/ProgramView.swift, Features/Quran/QuranPager.swift, Features/Quran/QuranReaderView.swift, Components/QuranMarginOverlay.swift, Tests/QuranAudioTests.swift, UITests/PhaseOneUITests.swift, UITests/ReaderUITests.swift et le projet Xcode existant.

## Complément — répétitions audio natives
Le moteur reprend la transition du lecteur React Native (src/core/audio.ts), sans modifier ce dépôt. Chaque verset peut être répété avant le suivant, ou le passage entier peut être rejoué. Choix rapides 1/2/3/5/10/20, nombre personnalisé jusqu’à 999, continu, arrêt à la fin, vitesse 0,75/1/1,25 et pauses 0/2/5/10 secondes. Une marge de transition de 200 ms est conservée entre versets distincts.

La sheet Réglages audio permet de choisir le verset, la page, la séance, une sourate ou un passage personnalisé dans une sourate. Le mini-player affiche le numéro d’écoute et un bouton Répétition. Les flèches restent dans les limites du passage. Réduire le player ne stoppe pas l’audio ; quitter le lecteur ou enregistrer sa voix annule les transitions différées. Une pause pendant l’intervalle garde la répétition à reprendre. Le même AVPlayerItem est réutilisé pour répéter le même verset après seek à zéro ; le cache audio reste identique.

Les réglages sont enregistrés immédiatement dans audioPreferences.nativeRepeat via ReaderOperation.audioRepeat, avec nativeRepeatUpdatedAt pour le rejeu. Le réciteur et les champs inconnus sont conservés. Ces champs natifs n’affectent pas les réglages locaux AsyncStorage du lecteur React Native. Aucun changement SQL. Le surlignage reste attaché au verset pendant toutes ses répétitions, puis suit le suivant.

Fichiers supplémentaires : Core/AudioRepeat.swift, Components/AudioRepeatSheet.swift, Tests/AudioRepeatTests.swift. Modifications : Services/QuranAudioService.swift, Components/QuranMiniPlayer.swift, Features/Quran/QuranReaderView.swift, Models/ReaderOperation.swift, Tests/QuranAudioTests.swift, UITests/ReaderUITests.swift et projet Xcode.

Tests supplémentaires : ordre chaque verset/passage, continu, boucle sans arrêt, validation des limites, persistance/rejeu, répétition réelle d’un fichier local puis passage au suivant et arrêt, pause/reprise pendant un délai, contrôle UI et surlignage conservé pendant la deuxième écoute.
Vérification du complément : 81 tests unitaires réussis et 13 parcours UI réussis lors de la série complète https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37224303049. Le quatorzième test UI échouait en sélectionnant une entrée du menu iOS via un mauvais ciblage XCTest ; le scénario utilise désormais le Stepper natif. Son rejeu ciblé a réussi : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37225677500 (1 test, aucun échec, archive Release et IPA non signée générées). Soit 95 tests distincts vérifiés entre la série complète et ce rejeu, sans nouvelle modification du code produit après la série complète. Le workflow permet ce rejeu ciblé via un filtre optionnel ; les lancements automatiques continuent d’exécuter toute la suite.

Captures du rejeu vérifiées : réglages des répétitions et écoute 2 / 3 du même verset avec surlignage conservé, sans déplacement du Mushaf. À la demande de l’utilisateur, les vérifications suivantes n’archivent plus automatiquement : archive/IPA optionnelles pour les jalons nécessitant une livraison sur iPhone.
