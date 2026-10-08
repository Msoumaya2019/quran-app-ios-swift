# Décorations des Mushaf — 8 octobre 2026

## Coran 1441

Après confirmation du propriétaire, le bandeau original Quran Android est intégré sans modification dans `Resources/coran_1441-chapter-header.png`. Les 114 positions originales sont conservées dans `Resources/coran_1441-headers.json`. `Mushaf1441Decoration` utilise les proportions originales ; `QuranPageCache` superpose seulement le bandeau. Les quinze images de lignes, leur position, la calligraphie et la Basmala restent inchangées. Les cercles numériques existants ne sont pas remplacés par des rosaces inventées.

Source épinglée : https://github.com/quran/quran_android/tree/188355356fce2ca731919611d677c6736ccee24d (dépôt GPL v3 ; autorisation de réutilisation confirmée par le propriétaire dans cette conversation).

Compilation et deux tests réussis : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37761450237 . Tests des pages 1, 2, 187, 600 et des 114 coordonnées.

## Tajweed QCF V4 / Mushaf 19

Les décorations utilisent les deux ressources originales QUL :

- https://qul.tarteel.ai/resources/font/459 — `quran-common.ttf`, 125 444 octets.
- https://qul.tarteel.ai/resources/font/457 — `surah-name-v4.ttf`, 215 592 octets.

Provenance, empreintes SHA256 et URLs originales : `Resources/QCFDecorations/SOURCES.md`. Les fichiers sont conservés sans modification. Les pages QUL décrivent leur intégration dans les applications. Les deux polices totalisent 341 036 octets et sont partagées entre toutes les pages ; les 604 polices de pages restent téléchargées à la demande.

Le composant officiel QUL `_chapter_name.html.erb` associe le glyphe `header` de la police commune au nom V4 `surahNNN surah-icon`. Le moteur local reprend cette association dans la ligne vide prévue pour le titre, sans déplacer aucun mot. Le cadre original est dessiné depuis son glyphe ; aucun cadre 1441 n'est utilisé. La Basmala conserve ses glyphes QCF, sans cadre ajouté. Les couleurs COLRv1 et les glyphes de fin de verset restent ceux du moteur existant.

Références QUL comparées aux données de test :

- https://qul.tarteel.ai/mushaf_layouts/19?page_number=1 : titre ligne 1, Basmala numérotée dans le texte.
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=2 : titre ligne 1, Basmala ligne 2.
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=187 : Tawbah, titre ligne 1, aucune Basmala.
- https://qul.tarteel.ai/mushaf_layouts/19?page_number=600 : titres lignes 4 et 11, Basmala lignes 5 et 12.

`TajweedDecorationResources` vérifie les empreintes et répare les fichiers incomplets. Les pages déjà téléchargées reçoivent les décorations hors connexion depuis les petites ressources embarquées. WKWebView lit uniquement les fichiers locaux autorisés. Le pont de sélection des versets, le lecteur audio, les annotations de séance et les autres moteurs ne sont pas remplacés.

## Vérifications

La révision `63f9f60` ajoute deux tests : réparation des ressources hors ligne ; rendu WebKit des quatre pages originales, présence des cadres, invariance des rectangles des mots et sélection du verset via le pont existant. Des captures natives sont conservées dans les résultats Xcode.

Compilation, tests et archive en cours : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37766364767 . Le résultat n'est pas annoncé comme réussi avant la fin de cette exécution.

Limites : comparaison visuelle et mesures sur iPhone physique encore nécessaires. La suite complète de la révision antérieure `19c13c3` comportait trois échecs UI (récitation administrateur, réglages de rythme de révision, accessibilité du bouton de répétition). Aucun succès global de régression n'est annoncé : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37710139654 .

Aucune modification du projet React Native ni de Supabase dans cette étape.
