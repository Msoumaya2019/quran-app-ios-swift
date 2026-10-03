# Rapport phase 1

Date : 4 octobre 2026. Version native0.1.0(1), dépôt privé `Msoumaya2019/quran-app-ios-swift` distinct de RN.

## Création

Architecture SwiftUI avec MVVM léger : AppStore coordonne la session et le snapshot, HomeRepository lit le backend, AuthService gère Supabase Auth, LocalStorageService et KeychainVault isolent les fichiers et secrets. Views dans Features, composants partagés dans Components, modèles dans Models, projection pure dans Core. Inventaire exact des fichiers via Git ; points d’entrée `App/CoranNativeApp.swift`, `Features/Navigation/RootView.swift`, `Features/Home/HomeView.swift`, `Features/Auth/AuthView.swift`.

## Dépendances / backend

SwiftUI, Foundation, Security/Keychain, Network, UIKit pour haptics. Seule dépendance tierce : Supabase Swift2.33.1 via SPM. Même backend `npbwnvrqmajwqtnncuyv`. Auth GoTrue, lecture `user_state(user_id,data)`, nom `friend_profiles`, RPC `daily_content_for_date` et `quiz_snapshot`. Aucun upsert de user_state, aucune migration/table/colonne/policy modifiée.

## Auth/session

Connexion et inscription avec compte existant, email de confirmation, récupération via lien, changement de mot de passe. SDK tokens stockés dans Keychain sous service propre à la nouvelle app ; identité locale également Keychain. Déconnexion scope.local pour ne pas révoquer RN. Deep link distinct corannative://auth. Ajouter ce redirect dans Supabase sans enlever le redirect RN. Clé client publique en fichier local ignoré / GitHub Secrets, aucun mot de passe ni service role dans Git.

## Offline initial

AppStore lit identité et cache utilisateur avant toute attente réseau. L’interface ne dépend pas du refresh. NWPathMonitor affiche uniquement une panne réseau réelle ; un échec Supabase affiche une note de synchronisation, pas une fausse bannière hors connexion. Refresh arrière-plan borné8/15secondes ; garde génération/UUID pour qu’une ancienne réponse ne réaffiche pas un autre compte. Snapshots écrits atomiquement avec protection de fichier. Pas encore de queue métier : aucune validation programme ou réponse quiz n’est implémentée en phase1.

## Navigation/Accueil

TabView cinq onglets exacts Accueil/Coran/Programme/Progrès/Amis, chacun NavigationStack. Swipe retour natif. Icônes header44pt, boutons44pt. Illustration et image lecture copiées depuis ressources actuelles. Accueil : salutation, nom réel, reprise, grille2×2, contenus admin en carrousel, Ma semaine, objectif et carte de signalement. Le contenu religieux n’est jamais inventé. Zones futures vers placeholders explicites. Dynamic Type, ScrollView et safe areas natifs. Apparence native persistante locale.

## Vérifications

Tests Xcode GitHub : contrat JSON/champs inconnus, calendrierParis/DST/dates anticipées/semaine, cache isolé, métadonnées, verses dédoublonnées, session locale immédiate sans réseau, confirmation email sans session, logout, login mock et réponse tardive après logout. UI Tests auth / home / cinq onglets / réglages / swipe retour. Captures attachées aux résultats Xcode. Connexion d’un compte réel et paramètres privés Supabase non vérifiés automatiquement ; aucun compte fictif créé en production.

## Limites / prochaines étapes

Windows n’exécute pas Xcode localement ; tests réels sur Mac GitHub. Mesures120Hz, Instruments, mémoire/CPU et comportement sur appareil exigent un Mac/iPhone plus tard. Distribution signée et APNs attendent configuration Apple. Phase2 non commencée. Aucun rendu Mushaf ni audio intégré. La phase3 fera converger la carte révision avec l’intégralité du moteur existant. Les identifiants ZIP test mentionnés dans la nouvelle demande ne sont plus des sources actives RN ; à arbitrer avant phase2.

Le résultat des tests GitHub et la vérification d’intégrité RN seront ajoutés après la compilation.
