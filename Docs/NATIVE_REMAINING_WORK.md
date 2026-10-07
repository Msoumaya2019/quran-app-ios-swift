# Suite de la migration native — état au 7 octobre 2026

Cette liste provient de l'inspection du code Swift actuel. Les rapports de phase anciens décrivent leur état à leur date ; plusieurs mentions « à migrer » y ont depuis été réalisées.

## Fonctions présentes

Lecteur Médine/1441 et téléchargement à la demande, cache/préchargement, centrage, audio et répétitions immédiates, actions des versets, difficulté, traduction, marque-pages, reprise, enregistrement, programme modifiable, révisions/consolidations et validation partielle, statistiques, amis/profils/consentements, messages/groupes, Quiz/défis/administration Quiz, signalements/modération, retours de récitations et corrections administrateur, rappels quotidiens locaux, administration des rappels/invocations (catégories, contenus, programmation, liens médias).

## Fonctions encore à compléter dans Swift

| Priorité | Fonction | Point d'intégration existant |
|---|---|---|
| 1 | Valider Realtime sur deux comptes réels | Abonnement natif aux messages directs/groupes implémenté, actualisation périodique de secours conservée |
| 2 | Vérifier les suspensions sociales avec un administrateur réel | Écran comptes et RPC existantes raccordés ; aucun accès administratif à auth.users depuis le client |

Les imports des médias privés, favoris hors ligne, audio éditorial, enregistrements d’invocations et photos de profil ont été ajoutés. Les tests simulateur ne remplacent pas les vérifications Storage/RLS sur Supabase réel.

## Configuration et tests externes restant nécessaires

- Notifications distantes APNs : le serveur actuel utilise les tokens Expo. Il faut préparer un raccordement natif séparé, une signature et les informations Apple nécessaires ; ne jamais transmettre un token APNs brut au moteur Expo.
- Connexion/authentification réelle, URL `corannative://auth`, permissions Storage/RLS et RPC effectivement déployées : à vérifier avec le compte Supabase réel.
- Échanges entre deux comptes réels, passage React Native → Swift → React Native et retour de connexion sur appareil : vérifier la conservation des données et la confirmation des files.
- Microphone, notifications et téléchargements avec fermeture/arrière-plan sur iPhone physique.
- Instruments et test de vingt pages sur chaque source : aucune mesure de mémoire, CPU ou fluidité physique n'est remplacée par un résultat du simulateur.

Les prochaines étapes doivent compléter ces services et écrans ; aucune nouvelle application, aucun monorepo et aucune suppression du schéma ou des données existantes.
