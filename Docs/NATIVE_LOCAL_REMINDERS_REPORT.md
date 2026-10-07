# Rappels natifs — 7 octobre 2026

Réglages → Notifications et rappels propose deux rappels quotidiens indépendants : apprentissage et révision. L'heure et l'activation sont enregistrées immédiatement dans le cache et la file de synchronisation existante. Aucun aperçu ni bouton de validation.

## Contrat et fonctionnement

- Les clés partagées `notifications.learning` et `notifications.revision` sont conservées.
- `notifications.nativeReminderTimes` conserve les heures/minutes natives ; `nativeRemindersUpdatedAt` protège contre les opérations plus anciennes. Les autres préférences restent intactes.
- `UNCalendarNotificationTrigger` répète à l'heure locale de l'iPhone sans fuseau fixe, y compris lors des changements d'heure.
- L'autorisation iOS est demandée seulement avec le bouton explicite. Sans autorisation, aucune notification n'est programmée.
- Les identifiants stables empêchent les doublons. La réconciliation est sérialisée et protégée contre le changement de compte pendant un appel asynchrone.
- La déconnexion retire uniquement les rappels natifs de cette application ; un appui ouvre Programme pour le compte concerné.
- Les rappels sont quotidiens et génériques : ils ne prétendent pas qu'une séance particulière est due.

## Fichiers

Nouveaux : `Core/ReminderSettings.swift`, `Services/LocalReminderService.swift`, `Features/Settings/ReminderSettingsView.swift`, `Tests/ReminderTests.swift`.

Intégration : AppStore, ReaderOperation, CoranNativeApp, RootView, SettingsView, tests UI et projet Xcode généré.

## Vérification et limites

134 tests unitaires réussis sur le commit 80ab536, dont permission refusée, déconnexion, changement de compte pendant la programmation et conservation des préférences. Le premier test UI a touché le centre du libellé du commutateur ; la nouvelle exécution touche le contrôle iOS situé à droite. Ce parcours a réussi sur le commit 85f49d0 : activation immédiate, retour aux réglages, réouverture conservant l'activation et désactivation. Run Xcode : 37612642434, simulateur iPhone 17 Pro Max. Cette exécution compile aussi le correctif de stockage des corrections vocales.

Aucune migration SQL. Les notifications distantes de messages/défis/corrections nécessitent encore la configuration native APNs et ne sont pas annoncées comme actives. La livraison d'une notification locale sur un vrai iPhone reste à vérifier.
