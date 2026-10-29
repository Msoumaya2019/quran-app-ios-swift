# Synchronisation fonctionnelle Expo → Swift · 29 octobre 2026

Référence inspectée en lecture seule : `Msoumaya2019/coran-memoire`, branche `feat/roqya-audio-space`, commit `b0afa0f3f177c99b401d3ec427187b8ba0eb7c81` (PR #2). `main` reste à `f538ae37565abf70032e7e215fe57c8b96c2152f`. Les nouveautés ne sont donc pas encore sur la branche principale Expo. Aucun fichier Expo/Android modifié.

## Changements natifs

- Quiz : séries solo de 1 à 10 questions aléatoires selon le catalogue, mêmes RPC `quiz_start_solo` / `quiz_answer_solo`, première réponse conservée côté serveur. Pas de solution dans la série initiale ; correction seulement après confirmation. Reprise d’une série tant que l’état Quiz reste chargé ; aucune série incomplète n’est restaurée après arrêt forcé. Pas de création de défi parallèle.
- Administration Quiz : source/explication facultatives selon le nouveau contrat backend ; rapport paginé de 50 réponses pour tous les modes et filtre par question. Les snapshots historiques du serveur restent la source de la correction.
- Roqya : accès depuis Accueil sans sixième onglet ; catalogue `roqyas → roqya_audios → roqya_reciters`, récitateurs, favoris/historique local par compte, streaming via le lecteur de récitations existant, vitesse, position/reprise, téléchargements réels réutilisant `QuranDownloadTransfer`, suppression locale. Cache public du catalogue ; URLs signées privées non persistées. Un fichier n’est reconnu installé qu’après transfert réussi et manifeste cohérent avec taille/source et validation AVFoundation du fichier audio. Les téléchargements continuent lors d’un changement d’écran ; pas de reprise en arrière-plan après arrêt forcé garantie.
- Administration Roqya : mêmes tables/RLS que la version Expo, création/modification/désactivation des contenus, récitateurs et audios ; import fichiers MP3/M4A et images via Supabase Storage. Un envoi ne montre pas de faux pourcentage. Audios limités à 200 Mo, images 10 Mo. Les fichiers importés mais jamais associés peuvent nécessiter un nettoyage administrateur ; pas de suppression automatique de médias existants.
- Coordination audio : propriétaire audio unique entre Coran, récitations, Roqya et microphone. Aucun nouveau moteur de récitation coranique.
- Modération : destinataire / nom de groupe depuis `admin_messages_with_recipients`, repli sur la liste sécurisée précédente si le RPC n’est pas disponible. Le RPC Expo fournit les 100 messages les plus récents.
- Activité : lecture optionnelle de la dernière session Expo via `admin_last_app_usage` uniquement après réussite du contrôle administrateur désigné natif. Affichage distinct, sans addition/double comptage. Aucune nouvelle collecte activée ; consentement et activation du suivi natif inchangés. Le SQL Expo de collecte n’est pas réappliqué automatiquement.
- Les unités page/rubu’ sur petites sourates étaient déjà corrigées en Swift (`MultiSurahProgramTests`) ; pas de second moteur ajouté.

## Backend

Scripts recopiés **à l’identique** de la branche Expo dans `Supabase/` : `quiz-solo-admin.sql`, `roqya.sql`, `roqya-admin.sql`, `admin-message-recipients.sql`. Ne pas les exécuter de nouveau si déjà appliqués. Sinon, après les scripts Quiz/Social existants : quiz-solo-admin ; roqya puis roqya-admin ; admin-message-recipients. Le script Quiz assouplit explicitement les contraintes source/explication ; aucun historique supprimé. Pas de migration exécutée sur la production depuis cette tâche. La compilation de l’IPA ne prouve pas que ces RPC sont installés dans Supabase.

## Vérifications

- Générateur Xcode déterministe et contrôle que le dépôt Expo est intact.
- Tests de série solo : correction après confirmation, verrouillage, confirmation perdue/premier choix serveur, changement de compte en vol, rejet de séries dupliquées.
- Tests Roqya : URLs sûres, filtrage des médias désactivés, isolation/persistance des favoris, détection d’un fichier incomplet ou d’une source modifiée, coordination audio, validation admin.
- Test UI du parcours Solo → réponse → correction → résultat. Les fixtures techniques ne sont utilisées qu’en Debug.
- 15 tests de référence de la branche Expo exécutés sur une copie isolée : quiz solo/RLS, Roqya/catalogue/uploads/RLS, activité et destinataires de messages : tous réussis.
- Résultats Xcode et lien de livraison à compléter après exécution GitHub Actions. Essais réseau réels avec compte administrateur et tests physiques iPhone non encore attestés.

## Limites de cette mise à jour

Le catalogue et l’administration Roqya sont maintenant disponibles, mais la minuterie de sommeil et les commandes d’écran verrouillé de la branche Expo ne sont pas encore portées. Les importations administrateur indiquent l’état d’envoi sans pourcentage d’upload. Les téléchargements ont, eux, une vraie progression en octets. Les interfaces et les services sont testés avec des fixtures et le SQL dans une base isolée ; la publication de contenus avec un vrai compte et une écoute prolongée sur iPhone doivent encore être vérifiées.
