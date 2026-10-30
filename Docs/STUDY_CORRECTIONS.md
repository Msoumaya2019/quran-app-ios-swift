# Corrections de connaissances et de révisions

Accès : Réglages → Mon programme → Modifier mes connaissances / Modifier mes révisions effectuées, et Progrès → Modifier mes connaissances et révisions.

- Choisir une sourate et une plage, ou toute la sourate, puis Appris / Connu à réviser / Pas encore appris. Date d’apprentissage éditable, sans changer les dates prévues des séances.
- Les changements écrivent les champs existants knowledge, memorizedAt, studyProgress, sessions, revisions et reviewConsolidations. L’initialisation des nouveaux versets réutilise VerseStudyChange. Changer la date d’apprentissage recalcule J+1 / J+3 / J+7 ; les consolidations de cet ancrage sont alors à refaire. Retirer un verset des connaissances ne supprime pas ses révisions historiquement effectuées.
- L’historique des révisions permet ajout, modification du passage et de la date, et annulation après confirmation. Les connaissances sont requises pour un ajout ; les doublons le même jour sont refusés. La date prévue d’une séance reste conservée, completedAt indique l’enregistrement de la correction, date indique le jour réel renseigné. Les consolidations antérieures et les difficultés ne sont pas annulées implicitement.
- Les crédits du cycle courant et les marqueurs de progression concernés sont ajustés ; les révisions annulées sont replacées dans la demande manuelle de révision.
- Les modifications passent par ReaderOperation et le cache local existants, puis HomeRepository et son compare-and-swap sur user_state. Aucun nouveau système de progression, aucune table ni migration SQL.
- Champs JSON natifs supplémentaires : nativeStudyCorrections (identifiants idempotents, valeurs précédentes et correction), nativeStudyCorrectionAt (conflits par verset). Le reset archive et vide ces champs. Compte, amis, conversations, préférences Mushaf, signets et difficultés inchangés.
- Une ancienne opération native concernant un passage corrigé ne peut pas ressusciter sa validation. Une ligne d’historique modifiée par un autre appareil n’est pas écrasée silencieusement par la transformation métier. L’application Expo ne connaît pas ces garde-fous natifs : une modification ultérieure depuis Expo utilise ses règles existantes, sans modification du dépôt Expo.

Validation : tests métier StudyCorrectionTests (plages invalides, connaissances partielles, dates, voisins préservés, doublons, historique périmé, replay hors ligne, reset, crédits du cycle), test UI StudyEditorUITests. Résultats Xcode à confirmer par CI avant livraison.
