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
