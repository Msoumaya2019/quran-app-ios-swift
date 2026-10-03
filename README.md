# Coran natif — SwiftUI

Deuxième application iPhone indépendante de [coran-memoire](https://github.com/Msoumaya2019/coran-memoire). Phase 1 uniquement. Aucun React Native, Expo, WebView ni dépendance JavaScript.

## Ouvrir et lancer

1. Sur un Mac avec Xcode 16 ou ultérieur, ouvrir `CoranNative.xcodeproj`.
2. Copier `Resources/Backend.plist` vers `Resources/Backend.local.plist` (ignoré par Git).
3. Renseigner `SUPABASE_PUBLIC_KEY` avec la **clé publique anon/publishable** du projet `npbwnvrqmajwqtnncuyv`. Ne jamais utiliser une clé service_role.
4. Choisir le schéma CoranNative et un simulateur iPhone iOS 17 ou ultérieur, puis Run.
5. Se connecter avec le même compte e-mail/mot de passe que l’application actuelle.

Le projet est déjà généré et partage un schéma Xcode. Si les fichiers source changent, `python3 Scripts/generate_project.py` régénère le projet de manière déterministe, sans outil tiers.

## Tests sur GitHub

Le workflow `ios-native.yml` exécute XCTest et UI Tests sur un Mac GitHub avec simulateur iPhone, puis archive une IPA non signée. Il utilise le secret de dépôt `SUPABASE_PUBLIC_KEY` (configuration publique de client, jamais service role). Les artefacts contiennent les rapports `.xcresult`, captures UI et logs. L’IPA non signée n’est pas directement installable sur un iPhone standard.

Les tests d’interface utilisent un compte fictif **local au simulateur**, uniquement dans DEBUG. Ils n’envoient aucun faux utilisateur ou programme à Supabase. Une connexion réelle au compte existant reste à valider sur simulateur/appareil par son propriétaire.

## Séparation et sécurité

Bundle ID distinct : `com.coranmemoire.native.ios`. Nom installé : **Coran natif**. Schéma de lien distinct : `corannative://auth`. Keychain distinct et tokens protégés `AfterFirstUnlockThisDeviceOnly`. La déconnexion est limitée à la session Swift et ne révoque pas la session React Native.

Aucune migration Supabase en phase 1. `user_state` est lu exclusivement ; les champs non migrés restent présents dans le JSON en cache. Aucun upsert de progression ou reconstruction de programme. Les préférences d’apparence sont locales à la version Swift.

## iOS minimum

**iOS 17** pour NavigationStack, ContentUnavailableView et NavigationDestination moderne. Swift 5 / Xcode 16+, Supabase Swift SDK **2.33.1**, version fixée. Aucun SwiftData nécessaire pour ce premier cache : fichiers Codable atomiques protégés, séparés par UUID utilisateur ; UserDefaults pour petites préférences ; Keychain pour identité hors ligne et session.

## Liens de confirmation / récupération

Dans [Supabase Dashboard](https://supabase.com/dashboard/project/npbwnvrqmajwqtnncuyv/auth/url-configuration), Authentication → URL Configuration → Redirect URLs → Add URL, ajouter **corannative://auth** et conserver **coranmemoire://auth**. Aucun certificat Apple n’est requis pour cette configuration additive. Sans cette autorisation, les liens e-mail Swift peuvent revenir vers le Site URL existant au lieu de l’application native. Ne change pas le Site URL actuel.

## Installation sur appareil

Dans Xcode → Target CoranNative → Signing & Capabilities : choisir sa Team Apple et vérifier la disponibilité du Bundle ID. Aucun Team ID, certificat, provisioning ou clé APNs n’est committé. Un compte gratuit peut servir à certains tests locaux limités ; TestFlight et la distribution nécessitent Apple Developer et App Store Connect.

Les notifications APNs, audio, lecteur, moteurs de programme, amis et quiz interactifs attendent les phases suivantes. Le backend Expo push actuel reste intact.

Voir [SWIFT_MIGRATION.md](SWIFT_MIGRATION.md), [analyse Supabase](Docs/SUPABASE_ANALYSIS.md) et [rapport phase 1](Docs/PHASE_ONE_REPORT.md).
