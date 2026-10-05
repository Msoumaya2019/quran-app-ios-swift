# Groupes natifs — 5 octobre 2026

## Intégration

Amis → Mes groupes donne accès à la liste synchronisée, à la création, aux invitations reçues et aux membres. Un membre accepté peut ouvrir la conversation. Le créateur peut nommer/retirer un modérateur et supprimer le groupe ; les modérateurs peuvent inviter/retirer des membres selon les permissions existantes. Les membres peuvent quitter le groupe. Les actions destructrices demandent confirmation.

Les conversations réutilisent ConversationView, ConversationLibrary, ChatSnapshot et ChatRepository : pagination, saisie, messages en attente, UUID stables et confirmation serveur. Le nom de l’expéditeur apparaît au-dessus des messages reçus. Aucun nouveau système social et aucune modification du dépôt React Native.

## Supabase

Aucune migration SQL. Réutilisation de friend_groups, friend_group_members, friend_profiles et friend_messages.group_id. RPC : create_friend_group, invite_group_member, accept_group_invite, decline_group_invite, set_group_moderator, remove_group_member, delete_friend_group. Les contrôles d’amitié, de rôle et de capacité restent exécutés par le serveur existant. Les droits affichés par l’interface ne remplacent pas les RLS.

## Hors connexion et isolation

La liste et les membres sont chargés immédiatement depuis des fichiers protégés, atomiques et propres au compte. Le réseau actualise ensuite ces données. Les mutations d’adhésion/création exigent une confirmation serveur ; aucun groupe fictif n’est créé hors connexion.

Les messages utilisent le cache et la file durable existants. Le champ facultatif groupRoom conserve la compatibilité avec les anciens fichiers de conversations privées. Les fichiers de groupes ont un préfixe group- ; une conversation privée et un groupe portant le même UUID restent distincts. Un message étranger ne peut confirmer une opération en attente. Une opération est supprimée de la file seulement après confirmation correspondante.

En cas de perte réseau pendant la création d’un groupe, actualiser la liste avant une nouvelle tentative : le RPC existant ne fournit pas de clé d’idempotence pour cette création. Les messages, eux, utilisent leur UUID stable.

## Fichiers

Ajout : Features/Friends/GroupsView.swift. Modifications : FriendsView, FriendsLibrary, ConversationView, ConversationLibrary, ChatSnapshot, ChatRepository, CoranNativeApp (fixtures DEBUG), ChatTests, PhaseOneUITests et références du projet existant. Le workflow accepte désormais les filtres XCTest au niveau du target ou d’un test précis.

## Vérification

Un test unitaire vérifie l’isolation des messages/caches privés et groupes, la compatibilité du cache et l’absence de confirmation par un message étranger. Deux parcours UI couvrent la conversation depuis le cache, la réouverture avec un message en attente et le refus explicite de création sans réseau.

Validation : 114 tests unitaires sans échec (run 37289667981), 12 parcours PhaseOne sans échec et archive Release réussie (run 37288916111), sur iPhone 17 Pro Max simulé. La capture de conversation a été contrôlée : message conservé, statut À synchroniser et champ de saisie accessibles. Aucune mesure Instruments ni essai entre deux comptes réels n’est annoncé comme effectué.

Une vérification supplémentaire du lecteur a échoué : déplacement de timeline à 0:16 au lieu de son milieu (run 37282908848), puis timeline désactivée avec durée nulle lors du rejeu isolé (run 37289673774). Le code audio n’a pas changé dans cette étape. Cette vérification reste à diagnostiquer ; ces résultats ne constituent pas une validation complète de l’audio sur appareil.

IPA arm64 non signée, version 0.1.0/build 1, 130 956 623 octets, 604 pages Médine et aucune fixture DEBUG. SHA-256 : c96bef64e32b64cb3580ef529d8f0e0037cd2a52ad3b38025782b49cef7cb3a7. Source : 8fb3175f3355d56e599ad11021b851bed723b6f5. Livraison : https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-groupes-2026-10-05.

## Limites restantes

Actualisation périodique, sans Realtime. Le contrat existant des accusés de lecture est réservé aux conversations privées : aucun faux compteur de lecture de groupe ajouté. Notifications APNs, lecture des récitations partagées et modération des messages restent à migrer. Les permissions et échanges entre comptes Supabase réels doivent encore être vérifiés sur appareil.
