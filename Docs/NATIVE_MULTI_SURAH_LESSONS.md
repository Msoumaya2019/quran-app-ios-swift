# Apprentissage et révision sur plusieurs petites sourates

## Cause et correction

Le calcul de la quantité reconnaissait la page et le rubu‘, mais la génération des séances et la projection du lecteur découpaient ensuite le passage à chaque fin de sourate. L’Accueil ne montrait que le premier fragment.

- Les nouvelles séances de quantité regroupent les versets contigus du bloc prévu, même à travers plusieurs sourates.
- Pour le sens depuis An-Nâs, les versets du bloc sont remis dans l’ordre du Mushaf lors de sa création ; l’ordre des unités quotidiennes reste celui du programme.
- Les fragments déjà enregistrés le même jour, contigus et de même unité page/rubu‘/nisf/hizb, forment un contexte commun dans le lecteur. Leurs identifiants et dates ne sont ni remplacés ni fusionnés dans la base.
- Une validation du contexte commun est distribuée aux séances d’origine. Validation partielle, dates prévues, dates réelles et historique continuent à utiliser les services existants.
- En révision habituelle, la fin d’une sourate ne coupe plus une plage quotidienne contiguë. Une lacune inconnue coupe toujours la plage : aucun verset inconnu n’est ajouté.
- L’Accueil affiche le même passage et le même nombre de versets que Programme et le lecteur.

## Vérifications

Tests ajoutés pour la page 604 et le dernier rubu‘ dans les deux directions, reprise de trois séances anciennes, validation partielle puis complète sans modification d’identifiants/dates, rejeu idempotent et révision arrêtée par un verset inconnu. Test UI : ouverture de la page 604 depuis l’Accueil avec 0/15 versets et formulaire de validation couvrant les trois sourates.

Les 163 tests unitaires Xcode ont réussi, sans échec (run 37664443012). La vérification UI de la page 604 et l’archive iPhone ont réussi dans le run 37665367620 (commit 1462264d786a0452c2acefb9e90e651a55272f5d). L’IPA social publié précédemment ne contient pas ce correctif.
