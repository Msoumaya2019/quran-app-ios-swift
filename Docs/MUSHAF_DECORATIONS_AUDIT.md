# DÃ©corations des Mushaf â€” analyse du 8 octobre 2026

## Ã‰tat : restauration non terminÃ©e

Aucune dÃ©coration approximative n'a Ã©tÃ© ajoutÃ©e. Aucun changement Supabase ou React Native.

## Coran 1441

Le moteur `QuranPageCache` compose les quinze PNG originaux sur un canevas 1440 Ã— 2320. Les lignes restent Ã  `(2320 - 232) / 14 Ã— index`. La calligraphie des noms de sourate et de la Basmala appartient aux PNG. Les numÃ©ros sont actuellement reconstruits sÃ©parÃ©ment Ã  partir de `coran_1441-markers.json` ; ce ne sont pas des mÃ©daillons papier restaurÃ©s.

Les mÃ©tadonnÃ©es dÃ©jÃ  analysÃ©es de l'archive identifient chaque en-tÃªte par `[sourate, page, indexLigne, centreX, centreY]`. Exemples : Fatiha `[1,1,3,.5,.5]`, Baqarah `[2,2,3,.5,.5]`, Tawbah `[9,187,0,.5,.45689654]`, Al-Qariah `[101,600,3,.5,.505665]`, At-Takathur `[102,600,10,.5,.49433497]`. Ne pas substituer les coordonnÃ©es QCF Ã  ces donnÃ©es.

La rÃ©fÃ©rence officielle Quran Android utilise `common/drawing/src/main/res/drawable-xxhdpi/chapter_hdr.png`, ajoutÃ©e sÃ©parÃ©ment par `SuraHeader`. Son placement conserve les images : largeur `largeurPage Ã— 1038 / 1080`, hauteur proportionnelle au PNG, centre calculÃ© depuis la ligne et `centreY`. La calligraphie n'est pas redessinÃ©e.

RÃ©fÃ©rence Ã©pinglÃ©e : [Quran Android, rÃ©vision 188355356fce2ca731919611d677c6736ccee24d](https://github.com/quran/quran_android/tree/188355356fce2ca731919611d677c6736ccee24d).

Le dÃ©pÃ´t indique GPL v3 dans son LICENSE. Aucun fichier de licence distinct autorisant spÃ©cifiquement ce PNG n'a Ã©tÃ© identifiÃ©. Le PNG a Ã©tÃ© tÃ©lÃ©chargÃ© pour inspection en dehors du dÃ©pÃ´t Swift ; il n'est pas intÃ©grÃ© ni distribuÃ© dans l'application. Une autorisation distincte ou une dÃ©cision explicite sur la conformitÃ© de distribution est nÃ©cessaire avant intÃ©gration. Les cercles verts actuels correspondent au lecteur numÃ©rique ; leur remplacement par une rosace arbitraire serait infidÃ¨le.

## Coran Tajweed â€” QCF V4 / Mushaf 19

Le rendu local WKWebView utilise les glyphes originaux `code_v2`, leurs `line_number`, leurs `verse_key`, la police de chaque page et sa palette COLRv1 claire. Les glyphes de fin de verset sont conservÃ©s dans les mots ; ne pas les remplacer par les marqueurs du 1441.

Les noms utilisent `sura_names.woff2` du dÃ©pÃ´t officiel Quran.com (rÃ©vision `aff1a035b09b66f28047b3216edcae4c5c949a49`). Le composant officiel `src/components/chapters/ChapterIcon/index.tsx` affiche le numÃ©ro de sourate sur trois chiffres dans cette police. Ce composant ne fournit pas de cadre papier.

Le site fournit `public/bismillah.svg`, rÃ©fÃ©rencÃ© par `src/components/dls/Bismillah/Bismillah.tsx`. Sa prÃ©sence ne dÃ©montre pas qu'il corresponde Ã  l'ornementation de l'Ã©dition QCF V4 ; il n'a pas Ã©tÃ© substituÃ© aux glyphes de la Basmala. Les ressources examinÃ©es ne permettent pas encore d'identifier un bandeau papier QCF V4 et sa licence d'intÃ©gration.

La documentation [Quran Foundation sur les polices](https://api-docs.quran.com/docs/tutorials/fonts/font-rendering/) dÃ©crit les glyphes et les lignes. Elle ne constitue pas une source identifiÃ©e pour les ornements manquants. Les en-tÃªtes doivent rester dans les lignes vides existantes, y compris les dÃ©buts en milieu de page ; aucune ligne contenant des mots ne doit Ãªtre dÃ©placÃ©e. Tawbah ne doit jamais recevoir une Basmala. Fatiha conserve sa Basmala numÃ©rotÃ©e comme verset.

## VÃ©rifications rÃ©ellement disponibles

- Compilation et archive de la rÃ©vision `19c13c3` : rÃ©ussies, [exÃ©cution 37710141854](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37710141854), quatre tests Tajweed rÃ©ussis.
- Suite complÃ¨te de la mÃªme rÃ©vision : Ã©chec, [exÃ©cution 37710139654](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37710139654). Ã‰checs UI : ouverture de la rÃ©citation administrateur (Â« Yassine Â» introuvable), accÃ¨s aux rÃ©glages de rythme de rÃ©vision, bouton d'incrÃ©ment des rÃ©pÃ©titions audio sans rectangle accessible visible. Ne pas prÃ©senter cette suite comme entiÃ¨rement rÃ©ussie.
- Aucune comparaison visuelle rÃ©elle des pages 1, 2, 600 et Tawbah aprÃ¨s restauration : la restauration n'est pas encore effectuÃ©e.
- Aucune mesure physique iPhone de cette modification ; aucune validation mode avion supplÃ©mentaire.

## Conditions pour terminer

1. Obtenir une ressource originale 1441 autorisÃ©e pour la distribution de cette application.
2. Identifier le bandeau original correspondant prÃ©cisÃ©ment Ã  QCF V4, avec provenance, licence et proportions.
3. IntÃ©grer sÃ©parÃ©ment chaque dÃ©cor, Ã  partir de ses coordonnÃ©es propres, sans changer les images ou les mots.
4. Comparer les pages demandÃ©es avec les rÃ©fÃ©rences correspondantes et vÃ©rifier interactions, audio et lecture hors ligne.
5. Compiler et corriger les rÃ©gressions constatÃ©es, sans annoncer de tests non exÃ©cutÃ©s.


## Intégration 1441 après confirmation du propriétaire

Le 8 octobre, le propriétaire a répondu « oui » à la demande d'autorisation de réutilisation du bandeau. La ressource originale est conservée sans modification dans `Resources/coran_1441-chapter-header.png` ; les 114 positions originales sont dans `Resources/coran_1441-headers.json`. `Mushaf1441Decoration` calcule les rectangles avec les proportions officielles. `QuranPageCache` ajoute seulement le bandeau en noir à partir de son alpha. Les quinze rectangles des images de lignes, les médaillons numériques, les coordonnées des versets et la Basmala intégrée aux PNG restent inchangés. Aucun bandeau 1441 n'est utilisé pour Tajweed.

Des tests couvrent les pages 1, 2, 600, 187 (Tawbah), une page sans titre et les 114 coordonnées. Leur résultat Xcode sera vérifié dans GitHub. Pas de validation visuelle iPhone annoncée avant exécution.

Compilation Xcode et deux tests Mushaf1441DecorationTests réussis sur la révision 52c6ebd : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37761450237 . Les 114 positions ont aussi été vérifiées localement (limites verticales 33 à 1981 sur 2320). La comparaison visuelle sur iPhone reste à réaliser ; Tajweed n’a pas reçu de décor supplémentaire.
