# Modification native du programme

## Interface
Réglages → Modifier mon programme permet de choisir un objectif, le sens d’apprentissage, une échéance, une quantité par séance et les jours actifs. Enregistrer mon programme applique directement la modification : aucun aperçu ni confirmation supplémentaire.

## Conservation des données
Core/ProgramEdit.swift centralise le calcul. Les séances terminées et partiellement commencées conservent exactement leurs identifiants, plages et dates. Les autres séances ouvertes restent enregistrées avec le statut existant postponed ; de nouvelles séances sont calculées à partir du jour local de la modification. Les connaissances, difficultés, révisions et consolidations ne sont pas réinitialisées. Chaque nouvelle séance possède date et scheduledDate ; la validation ultérieure conserve ces dates prévues.

## Quantités et calendrier
Les quantités sont 1 à 5 versets, une demi-page, une page, deux pages, un rubu‘, un nisf ou un hizb. Les limites utilisent les divisions originales du catalogue. La demi-page reprend les poids des lettres arabes du projet React Native, dans Resources/quran-weights.json, sans modifier le texte ou les pages. Le calendrier grégorien utilise le fuseau capturé lors de la modification et l’ajout de jours calendaires, compatible avec les changements d’heure. L’échéance est enregistrée comme préférence ; elle ne remplace pas le rythme choisi par un rythme calculé automatiquement.

## Hors ligne et Supabase
La file readerOperations existante transporte un payload Codable ProgramEdit. Le cache par compte est écrit avant le message de succès. La synchronisation réapplique la mutation sur les données serveur courantes avec l’écriture conditionnelle existante. Les champs JSON supplémentaires nativeProgramEdits et nativeProgramSettingsUpdatedAt dédoublonnent les opérations et empêchent une ancienne modification native de remplacer une plus récente. Aucune table, colonne ou policy Supabase n’est modifiée. Les conflits avec une modification React Native ultérieure doivent encore être vérifiés sur un compte réel.

## Vérification
Cinq tests unitaires couvrent la conservation des séances, la sérialisation/rejeu, les modifications successives, les deux changements d’heure Europe/Paris, les divisions et les paramètres invalides. Un test d’interface ouvre l’éditeur depuis les réglages et enregistre directement hors ligne. Suite Xcode réussie : 55 tests unitaires et 10 tests d’interface, soit 65 tests sans échec. Archive iPhone non signée générée. Capture de l’enregistrement direct contrôlée sur simulateur iPhone 17 Pro Max : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37214295583.

## Fichiers
Core/ProgramEdit.swift, Features/Settings/ProgramEditorView.swift, Tests/ProgramEditTests.swift et Resources/quran-weights.json ajoutés. AppStore, SettingsView, ReaderOperation, QuranCatalog, la fixture DEBUG et le projet Xcode existants complétés. Le dépôt React Native reste inchangé.
