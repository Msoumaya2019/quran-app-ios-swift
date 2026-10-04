# Messagerie native — 5 octobre 2026

Conversations entre amis acceptés depuis le profil, messages texte, historique paginé à 50 lignes, cache protégé et file d’envoi durable par utilisateur/conversation. Curseur date + UUID afin de conserver les messages portant la même date. Les messages masqués et supprimés sont respectés.

Réutilise friend_messages, friend_message_hidden et friend_message_reads, ainsi que leurs règles d’accès existantes. Pas de SQL ni modification du dépôt React Native. UUID stable avant envoi et vérification du message serveur avant retrait de la file : une confirmation perdue ne crée pas de seconde insertion. Les marques de lecture utilisent la date d’un message serveur confirmé.

Validation : 100 tests unitaires et 19 tests UI réussis : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37240143621. Parcours de réouverture de conversation réussi, capture vérifiée sur iPhone 17 Pro Max simulé. Archive Release du commit 96423c16326cb078cba7b8a930b76dbddd97d778 : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37240170117. ZIP et Mach-O arm64 contrôlés, 604 pages Médine, aucun fichier de test. IPA non signée, 130700827 octets, SHA-256 63f343099f40689342fa4f85ee041c4b74e05b4059c9c5f0b1ae9fadad41c8ec.

Livraison : https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-messagerie-2026-10-05.

Limites : actualisation toutes les 15 secondes lorsque la conversation est visible ; reprise des envois en rouvrant la conversation. Groupes, notifications et lecture des récitations partagées restent à migrer. Les échanges réels entre deux comptes sur iPhone ne sont pas encore mesurés.

Fichiers ajoutés : Models/ChatSnapshot.swift, Repositories/ChatRepository.swift, Services/ConversationLibrary.swift, Features/Friends/ConversationView.swift, Tests/ChatTests.swift. Intégration dans FriendsLibrary, FriendDetailView, App, projet Xcode et tests UI.
