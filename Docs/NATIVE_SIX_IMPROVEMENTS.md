# Six améliorations natives — 14 octobre 2026

## Changements

- Réglages : suppression des blocs Tajweed dupliqués et de Version native ; les trois sources restent sélectionnables. Téléchargement/cache Tajweed conservés dans Téléchargements et sources.
- Profil : avatar ouvre Mon profil ; roue dentée ouvre Réglages. Nom affiché/photo/visibilité réutilisent friend_profiles et FriendsLibrary, sans deuxième profil. Le modèle actuel contient un nom affiché, pas des champs prénom/nom séparés. Progression issue de knowledge ; objectif et récitations existants.
- Apparence : Clair/Sombre/Automatique, persistés dans native.appearance ; couleurs adaptatives des composants et contrôles système. Images monochromes : papier sombre/encre ivoire sans changement géométrique ; couleurs saturées préservées. Tajweed utilise palette COLRv1 1, Basmala également ; cadre redessiné seulement en couleur depuis son alpha original. Aucun téléchargement supplémentaire de police sombre.
- 1441 : la chaîne des chiffres était encodée incorrectement. Conversion explicite de chiffres canoniques par scalaires U+0660…U+0669 ; mêmes coordonnées originales. Les 6236 marqueurs sont uniques et canoniques ; page 600 comprend Al-Adiyat 6–11, Al-Qariah 1–11, At-Takathur 1–8.
- Activité : collecte inactive par défaut. Le serveur et la participation de l’utilisateur doivent tous deux l’autoriser. Temps monotone au premier plan, checkpoints locaux toutes les 10 s, envois groupés chaque minute/au départ ; aucune reprise de temps pendant la fermeture. Une fermeture brutale peut perdre au maximum le dernier intervalle de 10 s. File locale protégée, propriétaire distinct, conservation 30 jours, plafond 1000 intervalles. RPC idempotente par utilisateur+intervalle ; aucun contenu, écran, appareil ou IP collecté par cette fonctionnalité.

## Backend à appliquer manuellement

1. Appliquer `Supabase/native-activity.sql` dans le projet Supabase existant. Aucune table/policy existante n’est supprimée ou renommée.
2. Définir native_activity_settings.admin_user_id avec l’UUID réel du propriétaire qui figure déjà dans app_admins. Pas d’UUID déduit ou injecté automatiquement. Seul cet administrateur lit les résumés ; les autres administrateurs sont refusés.
3. Faire valider par le responsable du traitement la base légale, l’information/politique de confidentialité, les droits et la durée de conservation. L’écran donne une information et une participation facultative, mais ne remplace pas cette validation RGPD.
4. Configurer une exécution quotidienne côté serveur de `select public.native_activity_purge();` (rôle service_role ou propriétaire DB), puis vérifier la tâche. Elle ne purge que les nouvelles données de suivi âgées de plus de 30 jours.
5. Après ces validations, renseigner legal_review_confirmed et retention_job_confirmed, puis enabled=true. Le consentement utilisateur reste nécessaire. Sans cette étape aucune collecte ne démarre.
6. Vérifier le refus avec un vrai JWT membre et un JWT d’un autre admin sur la production. Les tests PostgreSQL isolés couvrent la sécurité des fonctions ; ils ne prouvent pas l’état déployé de votre projet.

La dernière authentification provient exclusivement de auth.users.last_sign_in_at (événement Supabase, pas présence au premier plan). Les périodes utilisent le fuseau local demandé ; 7 jours calendaires incluent aujourd’hui. Temps d’utilisation limité aux personnes participantes et à l’app native, pas des statistiques fictives historiques de React Native.

## Validation

Tests Swift : tous les marqueurs 1441, conversion des chiffres, temps premier plan sans arrière-plan, transformations de pixels, persistance du mode sombre. Tests WebKit et UI de navigation existants/ajoutés. Les résultats vérifiés et les révisions sont consignés ci-dessous. Pas de Xcode ni d’iPhone physique sur cet environnement Windows.

Tests SQL en base PostgreSQL jetable : collecte désactivée, refus membre/autre administrateur/anonyme, refus tables brutes, double synchronisation, retrait de participation et absence de fausse authentification. Aucun secret ni compte réel utilisé.

Retrait de participation hors ligne : arrêt local immédiat, purge locale et demande d’effacement serveur conservée jusqu’au retour de connexion. Les données déjà envoyées ne peuvent être effacées du serveur sans réseau.

Au démarrage hors ligne, une autorisation serveur précédemment confirmée et la participation confirmée sont utilisables pendant 24 h au maximum. Après ce délai, aucun nouveau suivi ne démarre avant vérification serveur. Les sessions sont des passages au premier plan avec du temps actif mesuré, pas des connexions.

## Tests et résultats vérifiés

- Révision Swift `142e221` : compilation Xcode, **180 tests unitaires sans échec** et archive iPhone réussis : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38497218674 .
- Révision `75cb98b` : suite complète comprenant **180 tests unitaires et 38 tests UI sans échec** : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38495907947 . La dernière modification Swift après cette suite réutilise le même client Supabase pour le suivi ; les autres écrans sont identiques. La suite UI complète de `142e221` est également lancée : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38497214193 . Ne pas annoncer son résultat avant sa fin.
- Deux tests UI ciblés sur la séparation profil/réglages (clair/sombre) et les trois sources sans encart dupliqué : réussis : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38493104457 . Captures inspectées.
- Un test audio a rencontré un délai de chargement dans la première exécution ; les suites complètes suivantes et sa relance isolée ont réussi : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38493409895 . Aucun changement du moteur audio pour masquer cet échec.
- Dernière migration SQL : tests PostgreSQL de refus membre/autre admin/anonyme, tables brutes inaccessibles, idempotence, retrait de participation, désactivation sans propriétaire autorisé et suppression du compte propriétaire : réussis : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/38497915731 . Base jetable uniquement ; **migration non appliquée et accès non testé sur Supabase de production**.
- Captures générées en clair/sombre : Médine et 1441 pages 1/42/600 ; Tajweed pages 1/2/187/600. Rendus sombres de ces pages inspectés ainsi que le 1441 page 600 en clair. Bandeaux, Basmala, couleurs Tajweed et numéros de la page 600 restent visibles. Vérification des 6236 marqueurs par les données canoniques.

La dernière authentification est le champ Supabase `auth.users.last_sign_in_at`, tous clients confondus (y compris une authentification React Native réelle). Les ouvertures de l’app et les refresh tokens ne sont pas enregistrés par ce suivi comme des connexions. Source du comportement Auth examinée : https://github.com/supabase/auth/blob/master/internal/tokens/service.go . La palette sombre QCF utilise la palette officielle 1 : https://api-docs.quran.com/docs/tutorials/fonts/font-rendering/ .

## Limites

- Pas d’iPhone physique disponible : confort visuel, VoiceOver, tailles dynamiques extrêmes, verrouillage réel et mode avion physique restent à confirmer sur appareil. Les tests locaux du compteur et du rendu ne remplacent pas ces essais.
- La collecte reste désactivée jusqu’à la configuration serveur et la participation utilisateur. Le responsable du traitement doit valider la politique de confidentialité et les prérequis avant activation.
- Une fermeture brutale peut perdre les dernières secondes non checkpointées (au maximum l’intervalle de 10 s). La file locale est plafonnée à 1000 intervalles ; une absence de réseau très prolongée avec beaucoup d’utilisation peut limiter la période conservée. Il s’agit du temps mesuré disponible, pas d’un historique antérieur reconstruit.
- Les statistiques d’utilisation concernent uniquement l’application Swift. Les données déjà envoyées ne peuvent être effacées du serveur sans réseau ; le retrait local stoppe immédiatement le suivi et conserve la demande d’effacement.
- La migration ne modifie aucun schéma existant de progression, amis ou quiz. Le propriétaire désigné doit toujours figurer dans app_admins ; sans lui, le serveur désactive la collecte. La suppression d’un compte n’est pas bloquée par la nouvelle configuration.

## Fichiers réellement ajoutés ou modifiés

- .github/workflows/ios-native.yml
- .github/workflows/native-activity-security.yml
- App/CoranNativeApp.swift
- Components/AppCard.swift
- Components/QuranMarginOverlay.swift
- Components/TajweedMushafPageView.swift
- Components/ThemeManager.swift
- CoranNative.xcodeproj/project.pbxproj
- Core/MushafNightImage.swift
- Core/MushafVerseNumber.swift
- Core/ProgressProjection.swift
- Core/TajweedMushafHTML.swift
- Docs/NATIVE_SIX_IMPROVEMENTS.md
- Features/Friends/ConversationView.swift
- Features/Friends/MyProfileView.swift
- Features/Friends/SocialAccountsAdminView.swift
- Features/Navigation/RootView.swift
- Features/Quran/QuranPager.swift
- Features/Quran/QuranReaderView.swift
- Features/Settings/ActivityPrivacyView.swift
- Features/Settings/QuranDownloadsView.swift
- Features/Settings/SettingsView.swift
- Models/UserActivity.swift
- Repositories/ModerationRepository.swift
- Services/QuranPageCache.swift
- Services/UserActivityService.swift
- Supabase/native-activity-security-test.sql
- Supabase/native-activity.sql
- Tests/NativeImprovementsTests.swift
- Tests/TajweedDecorationTests.swift
- UITests/NativeImprovementsUITests.swift

## IPA de test

Release : https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-native-six-improvements-2026-10-14 . IPA non signé de 132 577 188 octets, archive ZIP vérifiée ; SHA256 `07bcbf8eab06dba3c003536e232be044480d9d993afe0b01169c9f7f9591bd34`. Une signature iOS est nécessaire pour l’installation. Code Swift 142e221 ; révision serveur b4dfda5, sans modification du binaire Swift.
