# Validation native des consolidations

## Portée
Ajout progressif dans le dépôt Swift existant. Le dépôt React Native et le schéma Supabase restent inchangés. Les validations d’apprentissage et de révision ne sont pas encore migrées.

## Interface
Depuis Programme, ouvrir une consolidation, puis Plus → Valider la consolidation → J’ai consolidé. La confirmation porte sur tout le passage. Le bouton est désactivé lorsque le passage ne comporte plus de validation applicable. Le Mushaf et ses coordonnées restent inchangés.

## Données compatibles
`Core/ConsolidationValidation.swift` conserve l’ancrage `learnedAt`, l’étape 1/3/7, la date locale de validation et son horodatage réel. Il met à jour les champs existants `reviewConsolidations.completed`, `completedAt` et `consolidationHistory`. Les dates théoriques `scheduledDates` restent intactes. Pour les données anciennes sans dates explicites, elles sont calculées à partir du jour d’apprentissage +1/+3/+7 en jours calendaires.

La validation ne concerne que les versets connus (`perfect` ou `review`) dont la date d’apprentissage correspond encore à celle de la séance. Elle ne peut pas sauter une étape. Une répétition de la même opération ne valide jamais l’étape suivante. Les événements utilisent les identifiants existants verset-date-étape. Aucun statut de difficulté n’est effacé.

## Hors ligne et synchronisation
Le payload est conservé dans la file existante `readerOperations` du cache par utilisateur. La sauvegarde locale précède la publication de l’état à l’écran. Après retour du réseau, `HomeRepository` relit `user_state`, applique l’opération à l’état serveur courant et réalise une écriture conditionnelle sur `updated_at`. Un conflit provoque une nouvelle lecture, avec au maximum quatre tentatives. Seules les opérations confirmées sont retirées de la file. Un client Supabase absent ne peut plus être considéré comme une confirmation.

## Fichiers
- Ajout : Core/ConsolidationValidation.swift, Tests/ConsolidationValidationTests.swift.
- Modification : Models/ReaderOperation.swift, Features/Quran/QuranReaderView.swift, App/AppStore.swift, Repositories/HomeRepository.swift, projet Xcode existant.

## Vérification
Tests ajoutés : validation anticipée, validation tardive, dates J+1/J+3/J+7, répétition après sérialisation de la file, exclusion des versets inconnus, protection après réapprentissage, conservation des difficultés. Vérification locale du projet généré et des 3279 fichiers React Native : réussie.

Compilation, 38 tests unitaires et 7 tests d’interface : réussis, soit 45 tests sans échec. Archive Release non signée et captures générées : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37203389145.

Une exécution antérieure a échoué sur le test existant de navigation rapide de vingt pages. Deux exécutions suivantes ont réussi la suite complète. Une vérification sur appareil réel reste nécessaire pour caractériser cette instabilité du test de simulateur.

## Limites
Le parcours de confirmation ajouté doit encore être vérifié sur iPhone réel. La synchronisation contre un compte Supabase réel n’a pas été exécutée dans cette étape. Les moteurs d’apprentissage et de révision, l’édition des objectifs et les annotations de marge natives restent à compléter. Aucune mesure Instruments sur appareil réel n’est présentée.
