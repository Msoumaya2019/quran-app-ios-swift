# Décorations des Mushaf — analyse du 8 octobre 2026

## État : restauration non terminée

Aucune décoration approximative n'a été ajoutée. Aucun changement Supabase ou React Native.

## Coran 1441

Le moteur `QuranPageCache` compose les quinze PNG originaux sur un canevas 1440 × 2320. Les lignes restent à `(2320 - 232) / 14 × index`. La calligraphie des noms de sourate et de la Basmala appartient aux PNG. Les numéros sont actuellement reconstruits séparément à partir de `coran_1441-markers.json` ; ce ne sont pas des médaillons papier restaurés.

Les métadonnées déjà analysées de l'archive identifient chaque en-tête par `[sourate, page, indexLigne, centreX, centreY]`. Exemples : Fatiha `[1,1,3,.5,.5]`, Baqarah `[2,2,3,.5,.5]`, Tawbah `[9,187,0,.5,.45689654]`, Al-Qariah `[101,600,3,.5,.505665]`, At-Takathur `[102,600,10,.5,.49433497]`. Ne pas substituer les coordonnées QCF à ces données.

La référence officielle Quran Android utilise `common/drawing/src/main/res/drawable-xxhdpi/chapter_hdr.png`, ajoutée séparément par `SuraHeader`. Son placement conserve les images : largeur `largeurPage × 1038 / 1080`, hauteur proportionnelle au PNG, centre calculé depuis la ligne et `centreY`. La calligraphie n'est pas redessinée.

Référence épinglée : [Quran Android, révision 188355356fce2ca731919611d677c6736ccee24d](https://github.com/quran/quran_android/tree/188355356fce2ca731919611d677c6736ccee24d).

Le dépôt indique GPL v3 dans son LICENSE. Aucun fichier de licence distinct autorisant spécifiquement ce PNG n'a été identifié. Le PNG a été téléchargé pour inspection en dehors du dépôt Swift ; il n'est pas intégré ni distribué dans l'application. Une autorisation distincte ou une décision explicite sur la conformité de distribution est nécessaire avant intégration. Les cercles verts actuels correspondent au lecteur numérique ; leur remplacement par une rosace arbitraire serait infidèle.

## Coran Tajweed — QCF V4 / Mushaf 19

Le rendu local WKWebView utilise les glyphes originaux `code_v2`, leurs `line_number`, leurs `verse_key`, la police de chaque page et sa palette COLRv1 claire. Les glyphes de fin de verset sont conservés dans les mots ; ne pas les remplacer par les marqueurs du 1441.

Les noms utilisent `sura_names.woff2` du dépôt officiel Quran.com (révision `aff1a035b09b66f28047b3216edcae4c5c949a49`). Le composant officiel `src/components/chapters/ChapterIcon/index.tsx` affiche le numéro de sourate sur trois chiffres dans cette police. Ce composant ne fournit pas de cadre papier.

Le site fournit `public/bismillah.svg`, référencé par `src/components/dls/Bismillah/Bismillah.tsx`. Sa présence ne démontre pas qu'il corresponde à l'ornementation de l'édition QCF V4 ; il n'a pas été substitué aux glyphes de la Basmala. Les ressources examinées ne permettent pas encore d'identifier un bandeau papier QCF V4 et sa licence d'intégration.

La documentation [Quran Foundation sur les polices](https://api-docs.quran.com/docs/tutorials/fonts/font-rendering/) décrit les glyphes et les lignes. Elle ne constitue pas une source identifiée pour les ornements manquants. Les en-têtes doivent rester dans les lignes vides existantes, y compris les débuts en milieu de page ; aucune ligne contenant des mots ne doit être déplacée. Tawbah ne doit jamais recevoir une Basmala. Fatiha conserve sa Basmala numérotée comme verset.

## Vérifications réellement disponibles

- Compilation et archive de la révision `19c13c3` : réussies, [exécution 37710141854](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37710141854), quatre tests Tajweed réussis.
- Suite complète de la même révision : échec, [exécution 37710139654](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37710139654). Échecs UI : ouverture de la récitation administrateur (« Yassine » introuvable), accès aux réglages de rythme de révision, bouton d'incrément des répétitions audio sans rectangle accessible visible. Ne pas présenter cette suite comme entièrement réussie.
- Aucune comparaison visuelle réelle des pages 1, 2, 600 et Tawbah après restauration : la restauration n'est pas encore effectuée.
- Aucune mesure physique iPhone de cette modification ; aucune validation mode avion supplémentaire.

## Conditions pour terminer

1. Obtenir une ressource originale 1441 autorisée pour la distribution de cette application.
2. Identifier le bandeau original correspondant précisément à QCF V4, avec provenance, licence et proportions.
3. Intégrer séparément chaque décor, à partir de ses coordonnées propres, sans changer les images ou les mots.
4. Comparer les pages demandées avec les références correspondantes et vérifier interactions, audio et lecture hors ligne.
5. Compiler et corriger les régressions constatées, sans annoncer de tests non exécutés.
