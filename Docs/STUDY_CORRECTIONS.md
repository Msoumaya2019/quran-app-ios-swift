# Corrections de connaissances et de révisions

Accès : Réglages → Mon programme → Modifier mes connaissances / Modifier mes révisions effectuées, et Progrès → Modifier mes connaissances et révisions.

- Choisir une sourate et une plage, ou toute la sourate, puis Appris / Connu à réviser / Pas encore appris. Date d’apprentissage éditable, sans changer les dates prévues des séances.
- Les changements écrivent les champs existants knowledge, memorizedAt, studyProgress, sessions, revisions et reviewConsolidations. Les actions groupées et les corrections détaillées utilisent le même StudyCorrection. Les nouvelles connaissances sont regroupées par plages contiguës afin de ne pas créer une opération et une ligne de révision par verset. Changer la date d’apprentissage recalcule J+1 / J+3 / J+7 ; les consolidations de cet ancrage sont alors à refaire. Retirer un verset des connaissances ne supprime pas ses révisions historiquement effectuées.
- L’historique des révisions permet ajout, modification du passage et de la date, et annulation après confirmation. Les connaissances sont requises pour un ajout ; les doublons le même jour sont refusés. La date prévue d’une séance reste conservée, completedAt indique l’enregistrement de la correction, date indique le jour réel renseigné. Les consolidations antérieures et les difficultés ne sont pas annulées implicitement.
- Les crédits du cycle courant et les marqueurs de progression concernés sont ajustés ; les révisions annulées sont replacées dans la demande manuelle de révision.
- Les modifications passent par ReaderOperation et le cache local existants, puis HomeRepository et son compare-and-swap sur user_state. Aucun nouveau système de progression, aucune table ni migration SQL.
- Champs JSON natifs supplémentaires : nativeStudyCorrections (identifiants idempotents, valeurs précédentes et correction), nativeStudyCorrectionAt (conflits par verset). Le reset archive et vide ces champs. Compte, amis, conversations, préférences Mushaf, signets et difficultés inchangés.
- Une ancienne opération native concernant un passage corrigé ne peut pas ressusciter sa validation. Une ligne d’historique modifiée par un autre appareil n’est pas écrasée silencieusement par la transformation métier. L’application Expo ne connaît pas ces garde-fous natifs : une modification ultérieure depuis Expo utilise ses règles existantes, sans modification du dépôt Expo.

Validation : tests métier StudyCorrectionTests (plages invalides, connaissances partielles, dates, voisins préservés, doublons, historique périmé, replay hors ligne, reset, crédits du cycle), test UI StudyEditorUITests. Résultats : 208 tests unitaires réussis, compilation et archive iPhone réussies (run 41063208108, source 86fc34f). Test UI réussi sur iPhone 17 Pro Max (run 41065716911, correction de défilement du test uniquement au commit 29aee41) ; capture contrôlée après enregistrement. Vérification physique sur iPhone et synchronisation entre deux appareils réels non exécutées.

IPA publié dans la release test-study-editor-2026-10-30. Taille 133759993 octets ; SHA-256 a9c9c4a3d612a5e3f05a906b68d4b04953d7ea86fe2c229a72cf2e5ac32d9522. IPA non signé, sans les ressources techniques ReaderTestFixtures.


## Sélection rapide comme au démarrage Expo

L’entrée Modifier mes connaissances ouvre désormais les cases à cocher Juz’ / Hizb / Sourates. Les trois vues se basent sur les mêmes identifiants canoniques (30 Juz’, 60 Hizb, 114 sourates) ; un état partiel affiche le nombre de versets connus. Cocher complète les connaissances manquantes, préserve les dates et consolidations existantes, puis enregistre immédiatement via la file existante. Décocher remet uniquement la division choisie à apprendre. L’éditeur détaillé reste accessible dans Passages partiellement mémorisés pour choisir une plage et corriger sa date.

L’écran de démarrage a été inspecté en lecture seule dans la référence Expo (src/App.tsx, étape 0) : listes de cases sourates / Juz’ / Hizb et passages partiels. Le code Expo n’a pas été modifié. La sélection Swift reprend ce fonctionnement dans une liste native avec un sélecteur de catégorie pour éviter de parcourir 114 sourates avant d’atteindre les Juz’.

Validation de cette évolution en cours : suite métier et archive 41069565425 ; deux parcours d’interface 41069563862 (sélection partagée Juz’/Hizb/sourates et éditeur de passage).
