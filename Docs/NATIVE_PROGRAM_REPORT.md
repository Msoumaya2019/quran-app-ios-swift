# Programme natif : consultation et accès aux passages

## Existant conservé

Le JSON Supabase existant et son cache par compte sont réutilisés. Les séances ne sont ni reconstruites ni replanifiées. Les lecteurs Médine/1441, le cache, l’audio, les récitations et les marque-pages restent les mêmes. Aucune migration Supabase ni modification React Native.

## Fonctionnement

Programme affiche les séances d’apprentissage du jour, la révision issue du cycle enregistré, les séances en retard, les consolidations et À venir. L’accueil ouvre directement le passage disponible depuis Apprentissage/Révision ; sans passage, il ouvre Programme.

La date affichée est scheduledDate, avec date en repli pour l’ancien format. completedAt ne sert jamais à changer cette date. La fenêtre À venir inclut aujourd’hui jusqu’à J+10 ; l’historique et les séances plus lointaines sont conservés dans les données. Les additions de jours utilisent un calendrier local, pas des durées fixes de 24 heures.

La consolidation lit reviewConsolidations, memorizedAt et knowledge. Seuls les versets connus sont proposés. La première étape non terminée J+1/J+3/J+7 est utilisée. Les dates théoriques sont lues dans scheduledDates, ou calculées depuis learnedAt pour l’ancien format. Des versets voisins de la même sourate, appris à la même date et ayant la même étape/date, sont regroupés.

QuranSessionContext conserve mode, passage et date prévue. Le lecteur ouvre la page correspondant au début du passage dans la source prête. QuranSessionHeader s’affiche en haut avec le mode et les pages ; il prend sa place au-dessus du viewport, sans overlay sur le texte arabe. Le mode classique ne montre aucune capsule. Les images et leur ratio sont inchangés.

## Limites de cette étape

Il s’agit de consultation et d’ouverture des passages. La validation native des séances, la génération de nouveaux programmes, l’édition des objectifs, les annotations de marge et les mutations difficulté/apprentissage ne sont pas encore migrées. Aucun bouton ne prétend valider ces opérations. Le calcul complet des révisions récentes/prioritaires/habituelles reste à migrer : la carte lit actuellement le cycle persisté et les reprises partielles disponibles. Le pourcentage hebdomadaire réutilise la projection existante, avec semaine lundi 00:00 local.

## Fichiers

Ajouts : Core/ProgramProjection.swift, Components/QuranSessionHeader.swift, Features/Program/ProgramView.swift, Tests/ProgramProjectionTests.swift.
Modifications : HomeView.swift, RootView.swift, QuranReaderView.swift, QuranMiniPlayer.swift (déplacement audio par accessibilité), HomeSnapshot.swift, CoranNativeApp.swift (fixture DEBUG locale uniquement), ReaderUITests.swift et références du projet Xcode.

## Vérifications

Tests ajoutés : date prévue conservée malgré completedAt, borne J+10, exclusion J+11, séances en retard, consolidations J+1/J+3/J+7, exclusion des inconnus, regroupement des passages, calendrier Europe/Paris été/hiver et refus des dates invalides. Parcours UI Programme → passage → capsule → retour Programme. Les 36 tests unitaires passent. Le premier parcours UI a révélé une zone centrale non interactive dans la ligne de séance : contentShape(Rectangle()) rend désormais toute la ligne cliquable, avec une hauteur minimale de 44 pt. Le parcours Programme → lecteur avec capsule → retour passe après correction. Un runner a rencontré un délai de l’automatisation du simulateur dans le test existant des vingt pages. La relance a validé ce parcours et révélé une limite du curseur audio : les modifications d’accessibilité ne déclenchaient pas toujours les événements de début/fin de glissement. Le binding déclenche désormais seek aussi dans ce cas ; le parcours attend l’état disponible du fichier avant le déplacement. Validation finale complète sur [GitHub Actions 37201903455](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37201903455) : **36 tests unitaires et 7 tests d’interface, zéro échec**, sur iPhone 17 Pro Max simulé. Archive Release non signée et captures exportées. Le test audio retrouve environ 30 secondes après déplacement au milieu du fichier local de 60 secondes ; la capsule et le retour Programme passent ; les vingt pages des deux sources passent.
