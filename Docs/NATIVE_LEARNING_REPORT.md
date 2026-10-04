# Validation native de l’apprentissage

## Réutilisation
Le projet Swift, sa navigation, son lecteur UIKit/SwiftUI et son cache restent en place. Le code React Native sert uniquement de référence en lecture. Aucune table, colonne ou policy Supabase n’est ajoutée ou modifiée.

## Interface
Programme → séance d’apprentissage → Plus → J’ai appris jusqu’ici. Un sélecteur natif permet de choisir le dernier verset réellement appris, avec confirmation explicite. La capsule affiche X/Y validés. La réouverture du lecteur choisit la page du premier verset restant. Aucun surlignage, changement de police, déplacement ou remplacement des pages du Mushaf.

## Service
`Core/LearningValidation.swift` porte toute la mutation métier. L’opération contient la séance originale, sa plage, sa date prévue, le dernier verset appris, la source/page et la date/heure réelle. Elle n’est applicable qu’à une séance encore ouverte dont l’identifiant, la plage et la date correspondent. Elle n’accepte jamais un verset hors passage.

Une validation partielle conserve la séance `todo`, compatible avec React Native, et écrit `studyProgress[learning:id]` avec statut `partial`. Une validation complète écrit `done`, `completedAt` et `completedDate` sur la séance originale. `date` et `scheduledDate` ne sont jamais remplacées. Les séances suivantes ne sont ni régénérées ni décalées.

Les validations utilisent les champs existants `start`, `end`, `through`, `page`, `source`, `updatedAt`, `status` et `validations`. Seule la portion non encore validée est créditée. Les connaissances deviennent `perfect`, les dates d’apprentissage déjà présentes sont conservées, et les nouveaux versets reçoivent leurs étapes de consolidation J+1/J+3/J+7. Les révisions initiales utilisent les identifiants existants `r-début-fin`. Aucun marqueur de difficulté n’est supprimé.

## Hors ligne
Le payload Codable utilise la file persistante existante `readerOperations`. Le cache par compte est enregistré avant de publier la modification à l’écran. La synchronisation réapplique l’opération sur l’état Supabase courant, avec l’écriture conditionnelle existante sur `updated_at`. Une validation rejouée ne crédite pas deux fois le même préfixe. Une séance supprimée, déplacée ou modifiée ne reçoit pas une ancienne validation devenue incompatible.

## Statistiques
Les séances disposant de validations détaillées ne sont plus comptées une deuxième fois comme un bloc complet au jour de leur achèvement. Exemple : 3 versets lundi puis 4 mardi = 3 lundi et 4 mardi. Le pourcentage hebdomadaire continue d’utiliser les dates prévues des séances, sans effacement d’historique.

## Fichiers
Ajouts : Core/LearningValidation.swift, Features/Quran/LearningValidationView.swift, Tests/LearningValidationTests.swift.
Modifications : Models/ReaderOperation.swift, Features/Quran/QuranReaderView.swift, Components/QuranSessionHeader.swift, Core/HomeProjection.swift, UITests/ReaderUITests.swift, projet Xcode existant.

## Vérification
Projet Xcode déterministe et intégrité des 3279 fichiers React Native : vérifiés localement.
Tests ajoutés : lundi validé lundi, mardi validé lundi, lundi validé mercredi, conservation des séances voisines, validation partielle puis complète, sérialisation/rejeu de la file, conflit entre deux préfixes, séance obsolète, conservation des difficultés/champs inconnus, dates des consolidations et statistiques 3+4.
Test d’interface ajouté : ouverture d’une séance locale, confirmation et affichage 1/7 sans réseau.
Suite Xcode réussie : 42 tests unitaires + 8 tests d’interface, soit 50 tests sans échec. Archive Release non signée générée et capture de validation vérifiée. Résultats : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37210083135.

## Limites explicites
Cette étape valide les séances déjà programmées. L’édition des objectifs et la génération native d’un nouveau programme ne sont pas encore migrées. Le moteur complet de révision reste à migrer. La synchronisation avec un compte réel et la confirmation sur iPhone physique restent à vérifier. Le test d’interface utilise un compte fictif local et ne transmet aucune donnée à Supabase.

La première exécution a validé les 42 tests unitaires mais a révélé que le message de réussite se trouvait hors écran dans la feuille de hauteur moyenne. La capture confirmait la validation 1/7. Le message a été déplacé en tête du formulaire ; la suite complète a ensuite réussi et la capture confirme le message visible sans défilement.
