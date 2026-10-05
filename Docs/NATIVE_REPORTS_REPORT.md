# Signalements natifs — 5 octobre 2026

## Fonctionnement
Accueil : carte « Un problème avec l’application ? », formulaire iOS modal avec poignée, cinq types existants, description limitée à 500 caractères Unicode, capture facultative et action d’envoi. Capture sélectionnée par le sélecteur système Photos, redimensionnée à 1600 pixels maximum avec orientation conservée puis convertie en JPEG, hors du fil principal ; plafond 5 Mio.

Réglages administrateur : liste des 100 derniers signalements, détail, capture privée par URL signée cinq minutes, passage à « Résolu ». Appartenance à app_admins vérifiée ; les permissions Supabase restent l’autorité finale. Aucune liste administrateur sauvegardée sur disque.

## Compatibilité Supabase
Réutilise app_problem_reports et le bucket privé problem-report-screenshots. Champs existants snake_case, identifiant UUID stable, chemin user_id/id.jpg, type français, platform ios, status open. Aucune migration SQL, aucune modification du dépôt React Native. L’administration React Native peut consulter les signalements envoyés par Swift.

## Hors connexion
Application Support/CoranNative/ProblemReports/<utilisateur>/pending.json et JPEG locaux, écriture atomique et protection iOS jusqu’au premier déverrouillage. Enregistrement local avant retour de succès. L’interface distingue un signalement enregistré d’un envoi confirmé. Reprise au lancement, retour au premier plan et reconnexion. Upload sans remplacement ; réutilisation de l’objet déjà présent après confirmation perdue, insertion idempotente par UUID, puis lecture explicite du même UUID/utilisateur. Suppression de la file uniquement après confirmation serveur et sauvegarde locale réussies.

Changement de compte : file publiée vidée, chargement de la seule file du nouvel utilisateur, génération empêchant la réponse d’une ancienne requête de modifier la nouvelle file. Les captures ne sont jamais publiques.

## Vérification
Tests : format serveur et limites de description ; fichier et capture conservés avant synchronisation ; réouverture après confirmation réseau perdue, même identifiant sans doublon ; isolation des comptes ; confirmation en retard après changement de compte ; deuxième signalement ajouté pendant le premier envoi, synchronisé dans la même opération. Test d’interface : ouverture du formulaire, type Audio, description, enregistrement hors connexion et conservation des cinq onglets.

La suite complète sur 321d07f a réussi : 112 tests unitaires et 22 tests d’interface, sans échec (37277667753). Une exécution antérieure (37276908465) a réussi les 111 tests unitaires et le formulaire hors connexion mais échoué sur la réouverture d’une conversation. La capture du défaut affiche une conversation vide ; l’initialisation du StateObject de conversation est désormais différée au montage de la destination, afin de relire le cache enregistré au lieu de capturer un modèle préparé avant l’envoi. Les dix parcours PhaseOneUITests sur la correction et l’archive Release ont réussi, sans échec (37279933046). Les cinq tests ciblés de la file de signalements ont réussi sur 6a2823f (37279422850). Ces vérifications ciblées complètent la suite complète précédente, sans prétendre à une nouvelle exécution complète unique sur le dernier commit. Le générateur Xcode trie désormais les chemins comme des chaînes pour produire le même projet sur Windows et macOS. Capture du succès hors connexion contrôlée sur simulateur iPhone 17 Pro Max. Le traitement réel avec un compte administrateur et une capture choisie dans Photos reste à vérifier sur iPhone. Aucun signalement de test envoyé dans Supabase depuis les tests automatisés.

## Fichiers
Models/ProblemReport.swift, Repositories/ProblemReportRepository.swift, Services/ProblemReportLibrary.swift, Services/ProblemScreenshot.swift, Features/Reports/ProblemReportSheet.swift, Features/Reports/ProblemReportsAdminView.swift, Tests/ProblemReportTests.swift. Intégration dans App, Accueil, navigation, Réglages et tests d’interface. L’entrée Mon objectif de l’accueil ouvre désormais l’éditeur de programme existant.

## IPA de test
Source : 8297703d8eb65a5031e6c45751cc56c65524ab05. [Version Signalements](https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-signalements-2026-10-05). IPA arm64 non signée, 130908780 octets, 604 pages Médine, aucune fixture Debug. SHA-256 : 50753c71c113cacd9ea07fff112de5d926c4325873aa2bfd6dd6949cb18f61c3. Signature Apple nécessaire pour l’installation sur iPhone.
