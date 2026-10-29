# Roqya — minuterie et commandes iOS

Suite de la mise à jour Expo → Swift, exclusivement dans le dépôt natif.

- Le lecteur `RecitationPlaybackService` conserve son moteur AVPlayer et la coordination `NativeAudioFocus` existants.
- Minuterie : désactivée, 5/10/15/30/60 minutes ou fin de l’audio. Échéance monotone fondée sur ContinuousClock, incluant la veille de l’appareil et indépendante des changements d’heure ; tâche annulée lors d’un changement d’audio ou d’un arrêt ; à l’échéance, pause conservant la position. Choix temporaire, aucune reprise automatique au lancement.
- Métadonnées iOS : titre, récitateur, durée, position et vitesse ; commandes lecture/pause, arrêt, déplacement dans l’audio et sauts ±15 secondes via MediaPlayer.
- Chaque commande et notification est liée à une génération du lecteur. Les anciens événements ne peuvent pas relancer une autre piste. Les gestionnaires sont retirés à l’arrêt et lors d’un changement de propriétaire audio.
- Appel/interruption ou retrait d’écouteurs : pause, reprise manuelle. Mode audio d’arrière-plan activé dans Info.plist ; l’enregistrement au microphone reste limité au premier plan et s’arrête au passage en arrière-plan.
- L’interface Roqya affiche la minuterie, le temps restant et les boutons ±15 secondes. Quitter volontairement cet écran arrête toujours l’audio, conformément au flux existant. Verrouiller l’iPhone ne constitue pas une navigation hors de l’écran.
- Aucun changement des pages Mushaf, des programmes, des préférences utilisateur existantes ou du schéma Supabase. Dépôt Expo inchangé.

Tests ajoutés : modèle d’échéance, changement/annulation de minuterie, commandes et métadonnées, fin de piste, transfert du focus et interruptions. Parcours UI avec audio technique local : minuterie, passage à l’arrière-plan, retour et fermeture. Les fixtures sont exclues de Release.

Tests physiques du verrouillage, écouteurs/Bluetooth et écoute prolongée à réaliser sur iPhone ; la simulation ne permet pas de confirmer tout le comportement matériel.

Références Apple : [MPRemoteCommand](https://developer.apple.com/documentation/mediaplayer/mpremotecommand), [MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter).

Horloge : [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock).

## Stabilité de l’interface

Le sélecteur de minuterie est un panneau de confirmation iOS explicite. La progression temporelle réutilise `QuranAudioTimeline` dans une sous-vue dédiée : les ticks audio ne reconstruisent plus les commandes ni le panneau de minuterie. Les métadonnées système sont mises à jour aux changements utiles (lecture/pause, durée, déplacement, vitesse), iOS interpolant la position entre ces changements. Un test protège cette séparation. La longue fixture UI est technique, locale et copiée uniquement en Debug ; elle n’est pas incluse dans l’IPA Release.

## Livraison et validation

- Commit de l’IPA : `3d6824e3683305a3aa2bff92b30d048208dd8677`.
- [Compilation et tests unitaires](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/40904099185) : 198 tests réussis, aucun échec.
- [Parcours UI](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/40904105977) : minuterie, arrière-plan, retour et arrêt à la sortie validés sur simulateur iPhone 17 Pro Max ; capture inspectée.
- L’ancien test a exposé une sélection de durée non trouvée pendant une écoute courte. Le panneau explicite, l’isolation de la timeline et une fixture technique plus longue ont été validés par le parcours complet.
- Icône incluse : `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName = AppIcon`. Source et prompt : [Brand/APP_ICON.md](Brand/APP_ICON.md).
- IPA arm64 / ZIP valide, mode audio d’arrière-plan présent, fixtures Debug absentes de Release. Taille : 133 700 079 octets.
- SHA-256 local et GitHub : `200c2deb2fd9e933160fba727fb96bde7b6619fd00a7347084ede62e28f8df44`.
- [Release iPhone](https://github.com/Msoumaya2019/quran-app-ios-swift/releases/tag/test-roqya-icon-2026-10-29), IPA non signé.
- Aucun changement backend. Contrôle du dépôt Expo : 3 279 fichiers suivis intacts, HEAD `f538ae37565abf70032e7e215fe57c8b96c2152f`.
