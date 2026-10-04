# Repères en marge et difficultés natives

## Sources réutilisées
Coran de Médine : bounds.json du dépôt React Native, copié sans modification dans Resources/medina-bounds.json, coordonnées sur les pages originales 1920 × 3106. Coran 1441 : coran_1441-bounds.json déjà présent, coordonnées 1440 × 2320. Les sources, images, numéros, ratio, pagination et rendu du Mushaf restent inchangés. Aucun fichier React Native modifié.

## Rendu
Core/QuranMarginGeometry.swift normalise les coordonnées existantes. Le premier fragment de chaque verset fournit son ancre ; les versets commençant sur la même ligne partagent un repère. Chaque page affiche uniquement les versets présents sur cette page. Les validations partielles d’apprentissage et de révision remplissent les repères déjà validés.

Components/QuranMarginOverlay.swift utilise un calque UIKit indépendant, transparent et sans interaction. Il suit le rectangle aspectFit centré de l’image, sans toucher aux contraintes de UIImageView. La ligne est fine et les pastilles font au maximum 24 points. Les repères restent strictement à gauche de toutes les coordonnées du texte. Si la marge est trop étroite pour un numéro lisible, un petit point remplace la pastille : le texte arabe ne reçoit jamais de fond, bordure ni surlignage. Apprentissage utilise l’accent actif ; révision/consolidation utilisent la couleur secondaire du thème.

Une difficulté est signalée par un repère rouge discret dans cette même marge, également en lecture classique. Aucun fond rouge n’est dessiné derrière les versets. Les changements d’annotations actualisent uniquement le calque ; ils ne décodent ni ne remplacent l’image du Mushaf. Lorsqu’UIKit réutilise une page retenue hors de la fenêtre courante, cette instance visible redevient la référence du cache de contrôleurs et reçoit les annotations actuelles.

## Actions et conservation
Lecteur → Plus → Versets difficiles de cette page permet de marquer ou retirer chaque difficulté personnelle. Le statut est enregistré dans les champs existants difficultyMarkers, reviewPriorityDue et difficultyHistory. Un marquage administrateur reste conservé et signalé lorsque l’utilisateur retire son propre marqueur. Les inconnus du JSON sont conservés.

Core/DifficultyChange.swift contient la mutation, avec un état cible explicite plutôt qu’un toggle rejoué. La file readerOperations et le cache par compte existants enregistrent la modification avant de mettre à jour l’interface. L’identifiant de l’événement dans difficultyHistory dédoublonne les rejeux. Le champ JSON supplémentaire nativeDifficultyUpdatedAt conserve la dernière date par verset pour empêcher une ancienne action native hors ligne d’annuler une action native plus récente. Aucune nouvelle table, colonne ou policy Supabase.

## Vérification
Tests ajoutés : persistance disque/file et retrait volontaire, marqueurs administrateur, historique et champs inconnus, rejeu et ordre des opérations, jour local Europe/Paris, couverture des 6236 versets, groupement par ligne, versets sur plusieurs lignes/pages, passage d’un seul verset, ratio/centrage portrait et paysage, absence d’interception tactile et de déplacement de UIImageView.

Tests d’interface ajoutés : marquer une difficulté depuis une séance, changer de source, fermer et relancer l’application sur un cache local réel de test, vérifier le statut puis le retirer ; ouvrir une consolidation et une révision et vérifier leurs repères et leur centrage. Les comptes/ressources de test sont DEBUG et isolés du Supabase réel. Résultats finaux : **64 tests unitaires + 12 tests d’interface, 76 réussis sans échec**, sur simulateur **iPhone 17 Pro Max**. Archive Release et IPA non signée générées : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37219844054. Les parcours de 20 pages sur les deux sources, l’audio hors ligne, l’enregistrement vocal, l’édition directe du programme et les validations partielles passent dans cette même suite.

Le passage intermédiaire 37218158473 a réussi les 64 tests unitaires, la persistance/retrait/changement de source des difficultés, les consolidations, les validations d’apprentissage/révision, les enregistrements et le parcours de 20 pages. Seul le test UI de seek audio a échoué : la capture et l’arbre d’accessibilité montrent une pause à 0:33 après le geste XCTest vers 50 %, alors que l’attente acceptait 0:28–0:32. La tolérance tactile devient 0:26–0:34 sur la fixture de 60 secondes ; aucun code audio de production modifié.

Les captures du passage intermédiaire et du passage final ont été examinées : Médine et 1441 montrent le premier repère rouge sans fond sous le texte ; consolidation et révision montrent les repères verts ; lecture classique conserve la page sans repères de séance. Les quatre modes ont ainsi été contrôlés sur les captures du simulateur. Les blancs internes des images originales, notamment la première page, sont conservés ; aucune découpe du Mushaf n’est appliquée.

## Limites
L’accès aux actions se fait dans Plus, sans nouveau geste sur le texte. Les petites marges affichent un point au lieu de numéros illisibles. Les essais sur iPhone physique et les conflits entre modifications natives et React Native sur un compte réel restent à vérifier. Les marqueurs administrateur ne sont pas éditables depuis cette interface utilisateur.

## Fichiers
Ajouts : DifficultyChange, QuranMarginGeometry, QuranMarginOverlay, DifficultVersesView, medina-bounds.json, DifficultyChangeTests et QuranMarginTests. Modifications : QuranPager, QuranReaderView, ReaderOperation, générateur/projet Xcode existants et tests/fixtures DEBUG.

Le premier passage des tests a détecté un écart numérique de 0,00000000000006 point dans une comparaison de hauteur et un tap au centre d’une ligne Toggle qui n’activait pas le contrôle à droite. Le test géométrique utilise désormais une tolérance de 0,001 point ; la page et ses calculs restent inchangés. La ligne de difficulté est un bouton natif entièrement cliquable avec un état accessible Normal/Difficile, sans dépendre d’une petite zone à droite.
