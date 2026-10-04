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

Validation complète réussie sur [GitHub Actions 37197302297](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37197302297) : **33 tests unitaires + 6 tests UI, zéro échec**, sur simulateur iPhone 17 Pro Max. Compilation, archive Release non signée et export des captures réussis. Le parcours de recherche Fatiha et les sélecteurs Juz’/Hizb passent, ainsi que les régressions audio, récitations hors ligne et vingt pages des deux sources.

Le premier run avait été refusé avant démarrage pour un problème de paiement/plafond GitHub. Sur autorisation explicite de l’utilisateur, le dépôt Swift est passé en public après contrôle de l’historique pour les formats de clés privées et configurations confidentielles. Le passage en public a débloqué l’exécution du workflow. Le dépôt React Native n’a pas changé de visibilité et reste intact.

Le lecteur reste accessible directement depuis l’onglet Coran ; cette étape ajoute son index au menu existant. Les mesures sur iPhone physique et la signature Apple restent séparées des tests simulateur.
