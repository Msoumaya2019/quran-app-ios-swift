# Index Coran natif

## Ajout

Dans le lecteur, **Plus → Sourates, Juz’ et Hizb** ouvre une liste native. Elle conserve le lecteur existant, la source sélectionnée et la page affichée jusqu’au choix d’une entrée. Recherche des noms français et arabes, des significations et des numéros. Segments Liste / Juz’ / Hizb, médaillon doré géométrique, informations Mecquoise/Médinoise et nombre de versets. Reprendre ma lecture utilise les données locales du compte.

Le catalogue original déjà inclus fournit 114 sourates, 30 Juz’ et 240 quarts. Les 60 Hizb regroupent quatre quarts consécutifs ; aucune approximation de vingt pages n’est employée. Les pages sont calculées à partir du mapping de la source courante. Le choix ouvre cette page dans le même lecteur, sans modifier les images, l’audio, les enregistrements ou les marque-pages.

## Fichiers

- Ajout : Features/Quran/QuranIndexView.swift et Tests/QuranIndexTests.swift.
- Modifications : Core/HomeProjection.swift, Features/Quran/QuranReaderView.swift, UITests/ReaderUITests.swift, références du projet Xcode existant.
- Aucune migration Supabase, aucun changement React Native, aucune nouvelle ressource Mushaf.

## Vérifications

Contrôle local des JSON : 114 sourates, 30 Juz’, 60 Hizb et couverture continue de tous les versets 1–6236. Vérification du générateur Xcode et intégrité des 3279 fichiers suivis React Native.

Deux tests unitaires ajoutés : continuité des divisions et mapping des deux sources. Un parcours UI ajouté : ouverture de l’index, segments Juz’/Hizb, recherche Fatiha, retour au lecteur.

**Ces nouveaux tests et la compilation Swift ne sont pas encore validés.** Le [run GitHub 37196706091](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37196706091) a été refusé avant démarrage du runner : GitHub signale un paiement récent échoué ou un plafond de dépenses à augmenter dans Billing & plans. Ce run n’a exécuté aucune étape Xcode et ne produit pas d’IPA. Les 36 tests réussis précédemment concernent la version précédente, avant l’ajout de cet index.

Après résolution du blocage, relancer ce workflow et inspecter la capture Index natif — sourates. Le lecteur reste accessible directement depuis l’onglet Coran ; cette étape ajoute son index au menu existant.
