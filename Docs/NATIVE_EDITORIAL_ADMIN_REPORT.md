# Administration native des rappels et invocations — 7 octobre 2026

## Intégration

Réglages → Administration → Rappels et invocations. Deux listes distinctes, catégories par type, création, édition, duplication, activation/désactivation, suppression confirmée, programmation par date et déprogrammation explicite. Pagination de 30 contenus. Formulaires natifs SwiftUI, thèmes existants.

Réutilisation de `daily_contents`, `content_categories`, `daily_content_schedule` et de la RPC `save_daily_content`. Aucune migration SQL, aucune modification du dépôt React Native. Le texte français et la source sont requis ; une invocation nécessite aussi l’arabe et la phonétique. Les médias utilisent des liens HTTPS validés. Les données religieuses proviennent exclusivement de l’administrateur.

Une programmation remplace uniquement le contenu du même type à cette date, conformément à la contrainte serveur existante. Une édition sans date conserve les programmations ; la désactivation ne supprime pas l’historique. Suppression du contenu uniquement après confirmation explicite (cascades existantes Supabase).

## Architecture et sécurité

- `Models/EditorialContent.swift` : brouillon, contrat serveur limité aux champs autorisés, dates strictes, liens HTTPS, catégories et ordre entier PostgreSQL.
- `Repositories/EditorialRepository.swift` : vérification de l’utilisateur et d’app_admins, lectures parallèles, RPC transactionnelle existante, vérification de la confirmation serveur.
- `Services/EditorialLibrary.swift` : état MainActor, pagination, mutations après confirmation, isolement par compte/génération.
- `Features/Settings/EditorialAdminView.swift` : listes, formulaires de contenu et catégories, programmation.
- `App/CoranNativeApp.swift`, `Features/Settings/SettingsView.swift` : raccordement à l’architecture existante.
- `Tests/EditorialTests.swift`, `UITests/PhaseOneUITests.swift` : validation, échecs réseau, reprises sans doublon, programmations, changement de compte et parcours réel de formulaire.

Les actions administrateur nécessitent une connexion. Un échec n’est jamais affiché comme une sauvegarde réussie. Le reste de l’application garde son fonctionnement hors ligne. Les tests d’interface utilisent uniquement des fixtures techniques DEBUG, exclues des archives Release.

## Limites de cette étape

Les liens d’image/audio peuvent être renseignés ou modifiés ; l’import direct de photos et fichiers vers le bucket privé sera ajouté ensuite. Les favoris et l’audio éditorial côté utilisateur restent à compléter. L’accès réel aux policies et RPC déployées doit être vérifié avec le compte administrateur : les tests simulateur ne prouvent pas le comportement d’un projet Supabase distant.

## Livraison iPhone parallèle

L’IPA publié `test-corrections-versets-2026-10-07` correspond au commit 9bbd28d, avant ce module éditorial. 140 tests unitaires et 32 tests UI réussis ; archive Release arm64, 604 pages Médine, aucune fixture DEBUG. SHA-256 : cc7f0be46e3e02dd48c2537a164122c9282cafba8a2126bbd0a3a6c925ae4806. IPA non signé.

## Vérification du module

- Compilation et 146 tests unitaires réussis sur 4c15a89 (run 37640209961, 0 échec).
- Sept tests éditoriaux réussis sur 341c7cd (run 37641140023), y compris la pagination après suppression.
- Premier scénario UI : arrêt lors de la saisie du champ Source après un défilement sous la barre de navigation. Correction dans 3f5c1f6 : fermeture explicite du clavier via « Terminé » et déplacement contrôlé du test.
- La vérification UI de ce correctif n’a pas pu démarrer : run 37642009645, acquisition du runner macOS échouée cinq fois. Les demandes de relance et de nouveau dispatch ont ensuite retourné HTTP 500. Cette vérification reste à effectuer ; ne pas présenter le module complet comme validé visuellement.
- Dépôt React Native conservé à f538ae37565abf70032e7e215fe57c8b96c2152f.


## Mise à jour — suite du développement

- Imports PhotosPicker et fichiers audio dans `daily-content-media`, lecture des images privées avec cache séparé par compte.
- Favoris dans `content_favorites`, cache local et file d’intentions persistante, confirmation serveur avant retrait de la file.
- Audio des contenus via le lecteur existant ; enregistrements d’invocations via `recitations`, `recording_type`, `invocation_id`, `invocation_snapshot`.
- 156 tests unitaires réussis sur 93b96e4 (run 37651261988). La suite complète de ce commit a également réussi (37651262635).
- Scénario UI de création et programmation d’un rappel réussi sur e74811a (37650543930), après correction du geste du test.
- Aucun SQL supplémentaire exécuté et aucune modification du dépôt React Native.
- Les nouveaux profils/Realtime/modération sociale sont en cours de vérification séparée ; le dernier IPA publié reste celui décrit ci-dessus.
