# Coran natif — SwiftUI

Deuxième application iPhone indépendante de [coran-memoire](https://github.com/Msoumaya2019/coran-memoire). Authentification, lecteur natif, audio et répétitions, apprentissage/révision/consolidation intégrés ; migration sociale en cours. Aucun React Native, Expo, WebView ni dépendance JavaScript.

## Ouvrir et lancer

1. Sur un Mac avec Xcode 16 ou ultérieur, ouvrir `CoranNative.xcodeproj`.
2. Copier `Resources/Backend.plist` vers `Resources/Backend.local.plist` (ignoré par Git).
3. Renseigner `SUPABASE_PUBLIC_KEY` avec la **clé publique anon/publishable** du projet `npbwnvrqmajwqtnncuyv`. Ne jamais utiliser une clé service_role.
4. Choisir le schéma CoranNative et un simulateur iPhone iOS 17 ou ultérieur, puis Run.
5. Se connecter avec le même compte e-mail/mot de passe que l’application actuelle.

Le projet est déjà généré et partage un schéma Xcode. Si les fichiers source changent, `python3 Scripts/generate_project.py` régénère le projet de manière déterministe, sans outil tiers.

## Tests sur GitHub

Le workflow `ios-native.yml` exécute XCTest et UI Tests sur un Mac GitHub avec simulateur iPhone. L’archive et l’IPA sont désactivées pour les petites corrections ; à chaque grand ajout fonctionnel, un lancement manuel avec `build_ipa=true` génère une IPA de test publiée sur GitHub. Il utilise le secret de dépôt `SUPABASE_PUBLIC_KEY` (configuration publique de client, jamais service role). Les artefacts contiennent les rapports `.xcresult`, captures UI et logs. L’IPA non signée doit être signée avant installation sur iPhone.

Les tests d’interface utilisent un compte fictif **local au simulateur**, uniquement dans DEBUG. Ils n’envoient aucun faux utilisateur ou programme à Supabase. Une connexion réelle au compte existant reste à valider sur simulateur/appareil par son propriétaire.

## Séparation et sécurité

Bundle ID distinct : `com.coranmemoire.native.ios`. Nom installé : **Coran natif**. Schéma de lien distinct : `corannative://auth`. Keychain distinct et tokens protégés `AfterFirstUnlockThisDeviceOnly`. La déconnexion est limitée à la session Swift et ne révoque pas la session React Native.

Aucune migration Supabase. Le lecteur et les moteurs du programme synchronisent les mutations ciblées dans le JSON existant, avec contrôle de concurrence, dates prévues conservées et historique préservé. Les champs non migrés sont conservés. Les préférences d’apparence sont locales à la version Swift. Amis réutilise les tables et fonctions sociales existantes. Voir [SWIFT_MIGRATION.md](SWIFT_MIGRATION.md) et les rapports dans Docs pour les fonctionnalités vérifiées et les limites restantes.

## iOS minimum

**iOS 17** pour NavigationStack, ContentUnavailableView et NavigationDestination moderne. Swift 5 / Xcode 16+, Supabase Swift SDK **2.33.1**, version fixée. Aucun SwiftData nécessaire pour ce premier cache : fichiers Codable atomiques protégés, séparés par UUID utilisateur ; UserDefaults pour petites préférences ; Keychain pour identité hors ligne et session.

## Liens de confirmation / récupération

Dans [Supabase Dashboard](https://supabase.com/dashboard/project/npbwnvrqmajwqtnncuyv/auth/url-configuration), Authentication → URL Configuration → Redirect URLs → Add URL, ajouter **corannative://auth** et conserver **coranmemoire://auth**. Aucun certificat Apple n’est requis pour cette configuration additive. Sans cette autorisation, les liens e-mail Swift peuvent revenir vers le Site URL existant au lieu de l’application native. Ne change pas le Site URL actuel.

## Installation sur appareil

Dans Xcode → Target CoranNative → Signing & Capabilities : choisir sa Team Apple et vérifier la disponibilité du Bundle ID. Aucun Team ID, certificat, provisioning ou clé APNs n’est committé. Un compte gratuit peut servir à certains tests locaux limités ; TestFlight et la distribution nécessitent Apple Developer et App Store Connect.

Le lecteur classique natif est maintenant intégré : Coran de Médine, Coran 1441 à télécharger à la sélection, cache de trois pages, reprise, marque-pages et audio de base avec timeline, cache MP3 partagé et réciteur persistant. L’enregistrement vocal, la réécoute et la sauvegarde locale avec synchronisation vers les récitations Supabase existantes sont intégrés. Voir [rapport du lecteur](Docs/NATIVE_READER_REPORT.md) et [rapport des récitations](Docs/NATIVE_RECORDING_REPORT.md). Les notifications APNs, moteurs de programme, amis et quiz interactifs attendent les phases suivantes. Le backend Expo push actuel reste intact.

Voir [SWIFT_MIGRATION.md](SWIFT_MIGRATION.md), [analyse Supabase](Docs/SUPABASE_ANALYSIS.md) et [rapport phase 1](Docs/PHASE_ONE_REPORT.md).

L’index natif est accessible dans **Plus → Sourates, Juz’ et Hizb**. [Rapport et état de validation](Docs/NATIVE_INDEX_REPORT.md).

Programme affiche désormais les séances locales, les consolidations et une fenêtre À venir jusqu’à J+10, avec accès direct aux passages dans le lecteur. La validation et la génération native des séances restent à migrer. [Rapport Programme](Docs/NATIVE_PROGRAM_REPORT.md).
