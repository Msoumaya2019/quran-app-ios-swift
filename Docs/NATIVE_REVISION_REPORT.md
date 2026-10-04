# Validation native des révisions

## Périmètre
Le lecteur et les cycles déjà enregistrés sont réutilisés. Programme → séance de révision → Plus → Valider ma révision permet de sélectionner le dernier verset réellement révisé et une appréciation : Bien maîtrisé, Avec hésitations ou À retravailler. La validation conserve la plage originale et permet une reprise partielle au premier verset restant. Aucun changement du Mushaf.

## Dates et historique
Core/RevisionValidation.swift contrôle la séance et le cycle persisted avant toute mutation. scheduledDate reste la date théorique de la journée du cycle ; completedAt et completedDate reflètent la validation réelle. Les connaissances et dates d’apprentissage sont vérifiées pour ne pas créditer une ancienne séance après un nouvel apprentissage. Le rejeu d’une opération ne double pas l’historique.

Une validation hors ligne d’un cycle ensuite archivé peut créditer son historique sans modifier les difficultés, échéances ou consolidations du nouveau cycle. Une validation incompatible est ignorée. Les validations partielles habituelles React Native compatibles avec le cycle courant restent accessibles.

## Difficultés et consolidation
Avec hésitations et À retravailler ajoutent un marqueur utilisateur et une échéance prioritaire sans effacer les marqueurs administrateur existants. Bien maîtrisé ne supprime jamais automatiquement une difficulté. Une étape de consolidation déjà due peut être créditée par une révision compatible, comme dans le comportement existant.

## Stockage
Le payload Codable utilise readerOperations et le même cache par compte, puis l’écriture conditionnelle Supabase existante. Aucune migration SQL. Champs inconnus conservés.

## Tests et limites
Sept tests unitaires couvrent les dates anticipées/tardives, appréciations, reprise, rejeu, connaissances, cycles archivés et reprise React Native. Un test d’interface valide partiellement une séance locale. Résultat de la suite incluant l’éditeur : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37214295583 (réussie : 55 tests unitaires et 10 tests d’interface). La capture confirme le message de succès et 1/7 versets validés.

Cette étape ne génère ni ne fait tourner automatiquement les cycles de révision. La configuration des quantités quotidiennes et les files récentes/prioritaires complètes restent à migrer. Les essais sur iPhone physique et sur un compte Supabase réel restent à effectuer.
