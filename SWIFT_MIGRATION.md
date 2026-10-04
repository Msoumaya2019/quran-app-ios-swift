# Carte de migration Swift

Référence React Native : `Msoumaya2019/coran-memoire`, commit `f538ae37565abf70032e7e215fe57c8b96c2152f`, version 0.9.38(50). Ce document appartient au nouveau dépôt Swift, pas au dépôt existant.

## Architecture de l’application actuelle

`src/App.tsx` coordonne les écrans, état React, démarrage, authentification et lecteurs. La navigation principale est un état d’onglet Accueil/Coran/Programme/Progrès/Amis ; les lecteurs et outils sont présentés via des états d’écran et Modal. Les calculs métier vivent dans `src/core/*`; les services Expo/Supabase dans `src/services/*`; l’UI commune dans `src/ui/*` et `src/theme/*`. Les hooks React gèrent les effets, caches et moteurs audio ; aucune bibliothèque de store tiers n’est ajoutée dans Swift.

Le stockage SQLite (`storage.ts`) conserve app_state, account_state et pending_sync ; SecureStore conserve les sessions en fragments Keychain/Keystore. Quiz et signalements ont leurs files SQLite. Le moteur audio est réparti entre PassageAudioPlayer, audioFocus, verseAudioCache et quranAudioTimeline. Les rendus Quran incluent des images Médine/Tajwid, du texte dédié et le lecteur coranTest positionné. Les pages 1441 sont téléchargées à la demande.

## Carte fonctionnelle

| Fonction | Source RN | Logique / dépendances | Supabase | Équivalent Swift | Phase / statut |
|---|---|---|---|---|---|
| Connexion, inscription, récupération | services/sync.ts, App.tsx | Supabase Auth, URL mobile | auth.users / GoTrue | AuthService, AuthView, PasswordRecoveryView | 1 implémenté ; login réel à vérifier |
| Session sécurisée | services/authStorage.ts | Expo SecureStore, refresh | Auth | KeychainVault + SDK Supabase | 1 implémenté |
| Démarrage hors ligne | core/offlineAccess.ts, services/connectivity.ts | chargement local immédiat, réseau arrière-plan | Auth, user_state | AppStore, ConnectivityService | 1 implémenté et tests simulés |
| Cache par utilisateur | services/storage.ts | SQLite, account_state | user_state.data | LocalStorageService fichiers atomiques | 1 lecture/cache ; écritures métier en phase 5 |
| Navigation principale | App.tsx, ui/DesignSystem.tsx | 5 onglets, pas de Quiz en onglet | aucune | RootView + TabView + NavigationStack | 1 implémenté |
| Thèmes, accents, polices | ui/theme.tsx, theme/tokens.ts, theme/fonts.ts | 5 thèmes, 4 accents | préférences dans user_state.data | ThemeManager, SettingsView | 1 local, couleurs/illustrations conservées |
| Accueil | ui/MainScreens.tsx Home | reprises, grille 2×2, semaine, objectif | user_state, friend_profiles | HomeView, HomeProjection | 1 lecture dynamique, routes futures explicites |
| Rappel/invocation du jour | DailyContentsScreen.tsx, services/dailyContents.ts | contenu admin, sources, images, swipe | daily_content_for_date, daily_contents, schedule | HomeRepository, DailyContentView | 1 affichage lecture seule ; favoris/audio phase 4 |
| Lecteur et liste Coran | MushafPage.tsx, coranTest/*, ui/ZoomableReader.tsx | sources, pages, coordonnées, gestes, cache | préférence reader / bookmarks dans user_state | QuranService, reader natif UIKit/SwiftUI | 2 lecteur classique + index sourates/Juz’/Hizb intégrés, 39 tests Xcode réussis |
| Sources et téléchargements | core/quranSources.ts, services/quranDownload.ts, quranSourceReady.ts | lazy ZIP1441, source transition prête avant commit | user_state.reader | source registry, cache fichiers | 2 intégré : téléchargement 1441, cache et source atomique |
| Annotations marge | core/marginAnnotations.ts, ui/QuranSessionHeader.tsx | overlay indépendant, Mushaf intact | studyProgress | session header / overlay natif | 2/3 à faire |
| Audio verset/répétitions | PassageAudioPlayer.tsx, services/audioFocus.ts, verseAudioCache.ts, quranAudioTimeline.ts | Expo audio, plage, réciteur, répétition | préférences / fichiers | QuranAudioService AVFoundation | 2 audio de base intégré ; répétitions avancées à migrer |
| Enregistrement voix | RecitationRecorder.tsx, RecitationsScreen.tsx, services/recitations.ts | microphone, fichiers privés, partage | recitations, storage | recorder AVFoundation | Base intégrée : capture, réécoute, stockage local et sync ; partage/corrections à migrer |
| Programme / connaissance / objectif | core/program.ts, ui/GoalScreen.tsx, ui/MainScreens.tsx | schema1, knowledge, scheduledDate/completedAt | user_state.data | LearningProgramService | 3 consultation, accès aux passages et validation partielle/complète des séances existantes intégrés ; génération/édition des objectifs à migrer |
| Révision cycle / quantité | core/review.ts, ReviewDashboard.tsx | 7/14/21/30, Nisf/Hizb/Juz/2Juz, corpus connu | reviewCycle, reviewHistory dans data | RevisionProgramService | 3 à faire |
| Consolidation | core/review.ts, core/studyProgress.ts | J+1/J+3/J+7, dates et validations séparées | reviewConsolidations, consolidationHistory dans data | ConsolidationService | 3 consultation, ouverture et validation J+1/J+3/J+7 intégrées avec file locale et historique compatible |
| Difficile | core/review.ts, lecteur actuel | marque utilisateur/admin persistante | difficultyMarkers/history dans data | QuranProgressService | 3 à faire |
| Semaine / statistiques | core/weeklyProgress.ts, program.stats | calendrier local, dédoublonnage | sessions/studyProgress/histoires | HomeProjection / WeeklyProgressService | 1 affichage en lecture, 3 moteur complet |
| Amis / profils / demandes | SocialScreens.tsx, services/social.ts, avatars.ts | RLS, profils, liens et presence | friend_profiles, friend_links et RPC | FriendsService | 4 à faire ; nom lu sur accueil |
| Messagerie / groupes | SocialScreens.tsx, services/social.ts | Realtime, inbox, messages, read receipts | friend_messages, groups/members et RPC | messaging repository | 4 à faire |
| Question du jour / historique | ui/QuizScreen.tsx, core/quiz.ts, services/quiz.ts | réponse immutable, cache, outbox | quiz_snapshot, quiz_answer_daily | QuizService | 4 à faire ; disponibilité seulement sur accueil |
| Défis / quiz thématiques admin | ui/AdminQuiz.tsx, ui/AdminQuizSets.tsx | 5/10, 48h, mêmes questions, correction protégée | quiz tables et RPC | quiz views/repository | 4 à faire |
| Notifications | services/notifications.ts, AdminNotifications.tsx | Expo push / rappels locaux | push_devices, prefs, triggers | NotificationService UserNotifications + APNs | 4 à préparer, aucun token natif envoyé au moteur Expo |
| Administration | AdminAccounts, AdminDailyContents, AdminRecitations, SocialScreens | private.is_app_admin / RPC | migrations admin-* | admin natif | 4/5 à faire |
| Signalements | ui/ProblemReport.tsx, ui/AdminProblemReports.tsx, services/problemReports.ts | capture privée, outbox UUID | app_problem_reports, storage privé | problem report sheet | 4/5 à faire ; carte future présente |
| Bookmarks / reprises / traduction | BookmarksScreen.tsx, core/bookmarks.ts, data/translation-fr-rashid.json | local et merge stable | user_state.data | reader repository | 2/3 à faire |
| Sync offline complète | services/offlineSync.ts, core/offlineQueue.ts, offlineMerge.ts | snapshots bases, merge, ack, retry | user_state et RPC quiz | OfflineSyncService + queue locale | 5 à faire ; aucune mutation métier en phase1 |

## Contrat et limites phase 1

- Mêmes UUID auth/users, mêmes RLS ; lecture des données existantes sans changement de schéma.
- JSON conservé entier en cache. Aucun défaut Swift ne remplace les données serveur et aucune mutation de progression n’est envoyée.
- HomeProjection calcule les informations d’affichage (semaine / activité / reprise), ne crée ni ne valide de séances. La carte Révision lit le cycle déjà enregistré : le calcul complet récent/prioritaire/habituel attend la phase 3, donc elle peut rester à jour alors qu’un nouveau cycle doit être généré.
- La semaine suit actuellement le comportement RN : lundi 00:00 local. L’exigence historique évoque 00:01 ; vérifier cette minute de transition lors de la phase3, sans modifier RN ni effacer l’historique.
- Le lecteur classique et l’écran Programme en consultation sont intégrés. Les routes quiz/objectif/amis restent des espaces réservés pour les fonctionnalités non migrées.
- Les anciens ZIP test ont été retirés de la version actuelle et remplacés par1441. La nouvelle demande les mentionne à nouveau ; confirmer les versions à exposer en phase2 avant d’intégrer des ressources supplémentaires.
- Analyse des tables, fonctions, triggers et policies dans [Docs/SUPABASE_ANALYSIS.md](Docs/SUPABASE_ANALYSIS.md), inventaire détaillé [Docs/backend-inventory.json](Docs/backend-inventory.json). Les catalogues de production et configurations Auth/Storage/Edge Functions privées restent à vérifier avec accès propriétaire.

## Phases et arrêt

Phase1 : dépôt indépendant, auth/session/cache/thème/navigation/accueil et tests. **Arrêt obligatoire après rapport.** Phase2 autorisée par l’utilisateur : lecteur/cache/audio intégrés, validation Xcode réussie (19 tests). Phase3 : moteurs programme/révision/consolidation. Phase4 : social/quiz/notifications. Phase5 : offline complet, sync et instrumentation appareil.

## Sources SDK

[SDK Supabase Swift officiel](https://github.com/supabase/supabase-swift/tree/v2.33.1), [auth Swift](https://supabase.com/docs/reference/swift/auth-api). SDK fixé pour une compilation reproductible. Minimum iOS17. Pas de dépendance RN/Expo dans ce dépôt.

## État actuel du lecteur

Voir [NATIVE_READER_REPORT.md](Docs/NATIVE_READER_REPORT.md) : sources originales, UIKit, cache de trois pages, audio de base, reprise et marque-pages avec file locale compatible RN. Aucun fichier React Native modifié.

## Compléments phase 3 — 4 octobre 2026

La validation partielle et complète des révisions habituelles des cycles existants est intégrée, avec appréciation, conservation des dates, historique et reprise. Voir [NATIVE_REVISION_REPORT.md](Docs/NATIVE_REVISION_REPORT.md). La génération/rotation native des cycles et les files prioritaires/récentes complètes restent à migrer.

L’édition et la génération du programme d’apprentissage sont disponibles dans Réglages → Modifier mon programme. L’enregistrement est direct, sans aperçu ni confirmation supplémentaire. Objectif, sens, rythme et jours sont modifiables ; séances commencées, terminées et historique restent conservés. Voir [NATIVE_PROGRAM_EDIT_REPORT.md](Docs/NATIVE_PROGRAM_EDIT_REPORT.md). Ces compléments remplacent les mentions « génération/édition à migrer » du tableau et des rapports précédents.

Aucune migration SQL et aucun fichier React Native modifié. Tests Xcode de ces compléments : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37214295583 (65 tests réussis, archive non signée générée).

## Repères de séance et difficultés — 4 octobre 2026

Les annotations en marge sont intégrées au lecteur commun pour les deux sources. Elles utilisent les coordonnées originales et un calque UIKit indépendant, sans changer le centrage, la taille ou le rendu du Mushaf. Les repères d’apprentissage et de révision reflètent les validations partielles ; la consolidation utilise le même calque.

Plus → Versets difficiles de cette page permet le marquage personnel et son retrait, avec sauvegarde dans le cache par compte et la file existante. Les difficultés apparaissent dans la marge, également en lecture classique. Les marqueurs administrateur restent conservés. Ces fonctionnalités remplacent les mentions « annotations marge » et « difficile » à migrer du tableau précédent. Voir [NATIVE_MARGIN_DIFFICULTY_REPORT.md](Docs/NATIVE_MARGIN_DIFFICULTY_REPORT.md).

Vérification Xcode réussie : **64 tests unitaires et 12 tests d’interface (76 sans échec)**, sur simulateur iPhone 17 Pro Max. Archive Release et IPA non signée générées : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37219844054. Le dépôt React Native reste intact (3279 fichiers suivis vérifiés).

## Cycles de révision et suivi audio — 4 octobre 2026
La création et la rotation natives des cycles de révision sont disponibles. Réglages → Modifier mes révisions permet de choisir 7/14/21/30 jours ou 1 Nisf/1 Hizb/1 Juz’/2 Juz’ par jour, avec sauvegarde directe, fonctionnement local et synchronisation par la file existante. Le corpus ne contient que les connaissances éligibles et reste fixe pendant le cycle ; les dates prévues et les cycles archivés sont conservés. Ce complément remplace les anciennes mentions « génération/rotation à migrer ». Les files prioritaires/récentes complètes restent à migrer.

Le verset récité est maintenant teinté dans un calque UIKit attaché aux coordonnées originales des deux Mushaf. Les programmes restent indiqués seulement dans la marge. Le suivi audio ouvre automatiquement la page du verset si reader.followAudio est actif. La vérification de ce correctif a réussi : 75 tests unitaires + 13 tests d’interface, archive non signée, captures vérifiées (verset suivant et réglages hors ligne) : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37223089109.

Un complément ajoute les répétitions de chaque verset ou du passage entier, les plages (verset/page/séance/sourate/personnalisée), vitesse, pauses et nombre d’écoutes. Voir [NATIVE_REVISION_SCHEDULE_AUDIO_REPORT.md](Docs/NATIVE_REVISION_SCHEDULE_AUDIO_REPORT.md) pour le fonctionnement et les limites. Répétitions vérifiées : 81 tests unitaires et 13 parcours UI réussis dans la série complète, puis le quatorzième test UI réussi après correction de son ciblage XCTest. Archive Release et IPA non signée : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37225677500. Aucun code produit changé entre ces deux vérifications.
