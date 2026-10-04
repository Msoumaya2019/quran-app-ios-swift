# Lecteur natif — intégration progressive

## Existant conservé

Le dépôt Swift, le projet Xcode, l’authentification Supabase, la session Keychain, le cache par compte, les thèmes, l’accueil et les cinq onglets ont été complétés. Le dépôt Expo / React Native n’est pas modifié. Le même Supabase est utilisé sans migration de schéma.

## Ressources exactes

- **Coran de Médine**, identifiant partagé `traditional` : les 604 PNG originaux de `assets/mushaf/page001.png` à `page604.png`, copiés sans modification. Environ 112,7 Mio de ressources compressées, disponibles hors connexion dès l’installation.
- **Coran 1441**, identifiant partagé `coran_1441` : archive `https://files.quran.app/hafs/madani_1441/zips/images_1440.zip`. Téléchargement uniquement lors de sa sélection. Extraction de 604 × 15 images dans Application Support. Canvas original 1440 × 2320, lignes 1440 × 232 positionnées suivant le lecteur RN. Les numéros de versets utilisent les coordonnées du JSON original : le ZIP contient les lignes et le lecteur existant ajoute déjà ces numéros. Les données originales de coordonnées sont également conservées pour retrouver le premier verset de la page.
- Aucun ZIP test n’a été mélangé aux sources. Les futurs rendus peuvent être ajoutés à `QuranSource`.

## Architecture

`QuranReaderView` fournit les options et la barre d’actions. `QuranPager`, un `UIViewControllerRepresentable`, pilote `UIPageViewController` en transition scroll native avec ordre arabe. Chaque contrôleur affiche un `UIImageView` en `scaleAspectFit` : centrage horizontal et vertical dans la zone disponible, sans déformation ni scroll vertical. En lecture classique, une barre de navigation iOS compacte affiche le nom de la source. Le tap masque ou rétablit cette barre et les commandes. Le bord gauche est réservé au retour dans une navigation empilée ; les swipes internes tournent les pages. La Safe Area et les éléments SwiftUI inférieurs déterminent la hauteur disponible.

`QuranPageCache` décode hors du thread principal et conserve au maximum trois pages décodées. Les contrôleurs de page partagent ces images. La page courante est publiée avant le préchargement des voisines. Le changement de source vérifie les fichiers et prépare la page avant de remplacer la source affichée ; une erreur conserve le lecteur et sa source précédente.

## Reprise / marque-pages / compatibilité

Les opérations natives utilisent `lastRead`, `reader.mushaf`, `bookmarks`, `sourcePages` et les identifiants globaux de verset existants. Une suppression de marque-page crée un `deletedAt`, compatible avec la fusion RN. Le JSON complet et ses champs inconnus sont préservés.

Les changements sont enregistrés atomiquement dans le cache du compte avec une file `readerOperations` locale. La synchronisation relit `user_state` puis applique uniquement ces opérations ; la mise à jour est conditionnée au `updated_at` lu pour détecter un changement concurrent. Les opérations confirmées sont retirées de la file. Une répétition après une interruption conserve le même résultat, les dates et les tombstones. La synchronisation reprend au retour du réseau / à la réouverture / à la sortie du lecteur. Si aucun état RN valide n’existe encore pour un nouveau compte, les changements restent locaux ; ils ne remplacent pas un programme par un état incomplet.

## Audio

AVFoundation : lecture, pause, précédent, suivant, enchaînement verset par verset et choix Husary / Alafasy / Minshawi / Ash-Shatri. Les URL et identifiants de versets correspondent aux sources existantes. Les MP3 téléchargés sont conservés dans le cache natif et peuvent être réécoutés hors connexion. Le mini-player observe son service audio séparément : il ne pilote pas le rendu des images. Répétitions avancées, sélection d’une plage, surlignage audio restent à migrer. L’enregistrement vocal de base est intégré ; voir [rapport dédié](NATIVE_RECORDING_REPORT.md).

## Vérification

Des tests vérifient la conservation des champs inconnus, les suppressions persistantes, la relecture des anciennes sauvegardes, les limites de page et un parcours de 20 pages avec cache limité à trois images. Un test UI effectue le parcours dans les deux sources, avec des images 1441 originales préparées avant lancement ; ces fichiers de test ne sont pas inclus dans l’IPA Release.

Xcode GitHub sur iPhone 17 Pro Max : 16 tests unitaires et 3 tests UI réussis, archive iOS réussie. Le parcours de 20 pages dans chaque source, le changement de source sur place, les marque-pages et le retour par le bord gauche passent. Rapport : https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37165111376. Une IPA non signée est disponible dans les artefacts ; une signature Apple est nécessaire pour installation sur iPhone. La mémoire totale, le CPU, le taux réel d’images et les conflits de gestes sur iPhone demandent une mesure sur appareil avec Instruments. Aucun chiffre de fluidité 120 Hz n’est déduit d’un simulateur.

## Fichiers ajoutés et modifiés

Swift ajouté :
- Models/QuranSource.swift, Models/ReaderOperation.swift
- Services/QuranResourceService.swift, Services/QuranPageCache.swift, Services/QuranAudioService.swift, Services/QuranAudioCache.swift, Services/QuranAudioTimeline.swift
- Features/Quran/QuranReaderView.swift, Features/Quran/QuranPager.swift
- Components/QuranMiniPlayer.swift
- Tests/ReaderTests.swift, Tests/QuranAudioTests.swift, UITests/ReaderUITests.swift

Swift existant complété : AppStore, HomeSnapshot, HomeRepository, HomeView, RootView, SettingsView et PhaseOneUITests. Le projet Xcode existant et son générateur, le workflow GitHub, la documentation et les règles d’exclusion des ressources de test sont également mis à jour. Les ressources ajoutées sont les 604 PNG Médine et les JSON originaux bounds/markers 1441.

## Limites de cette étape

- Enregistrer reste une action indiquant la migration future ; aucune fonction RN n’a été supprimée.
- Le marque-page rapide utilise le premier verset de la page ; la sélection de verset par coordonnées viendra ensuite.
- L’audio ne suit pas encore visuellement les changements de page. Le choix du réciteur est maintenant enregistré localement et synchronisé dans audioPreferences.reciterId, sans remplacer les autres préférences.
- Les modes apprentissage/révision/consolidation sont déclarés dans l’architecture, mais leurs moteurs et annotations ne sont pas encore migrés.
- Les tests hors ligne utilisent des ressources locales et une session simulée. Le téléchargement complet sur appareil, l’auth réelle et la synchronisation avec un vrai compte demandent une vérification sur iPhone.
- Le temps de décodage d’une page est mesuré ; le temps total tap → première page, le CPU, le pic mémoire de toute l’app et le FPS réel ne sont pas encore mesurés avec Instruments.
- Pas de nouvelle table, colonne, migration ou policy Supabase.

## Mesures de décodage sur simulateur GitHub

Exécution du 4 octobre 2026 :

| Source | Premier décodage | Autres décodages observés | Trois images décodées en cache |
|---|---:|---:|---:|
| Médine | 41,7 ms | environ 36,8–55,7 ms | 71 562 240 octets (68,25 Mio) |
| Coran 1441 | 112,2 ms | environ 65,4–84,1 ms | 40 089 600 octets (38,23 Mio) |

Ces valeurs sont celles des tests unitaires de cache, pas la mémoire totale du processus ni un benchmark sur iPhone. Elles varient selon la charge du runner. Le parcours conserve trois pages au maximum ; Médine a produit 73 accès servis par le cache pendant le test. Les 19 tests passent. Le geste réservé au bord gauche déclenche une transition de retour native au relâchement ; il ne pilote pas encore une transition interactive de retour suivant le doigt. Les swipes de pages suivent le doigt via UIPageViewController.

## Complément audio — 4 octobre 2026

- `QuranAudioCache` centralise les MP3 locaux, partage les téléchargements simultanés et écrit les fichiers atomiquement. Les fichiers déjà téléchargés sont ouverts sans réseau ; un fichier vide n’est pas considéré comme disponible.
- Le verset suivant est préparé après le démarrage de la lecture. Une erreur de préchargement n’interrompt pas le verset courant.
- `QuranAudioTimeline` est observé uniquement par la timeline du mini-player. Les mises à jour temporelles toutes les 250 ms ne sont pas relayées à l’état du lecteur/Mushaf.
- La timeline affiche durée et position, permet de déplacer la lecture et conserve une zone tactile de 44 pt. Le mini-player peut être réduit et son espace est alors rendu au Mushaf.
- Les observers AVPlayer sont retirés lors du remplacement du lecteur. Les callbacks d’une ancienne lecture ne doivent pas modifier la lecture actuelle.
- Le choix du réciteur utilise une nouvelle opération locale `reciter`, dans la file existante. Elle modifie uniquement `audioPreferences.reciterId`, avec conservation des autres champs JSON. Pas de migration Supabase.
- Tests ajoutés : deux requêtes audio simultanées, réouverture du cache sans réseau, rejet/reprise d’un téléchargement vide, contrat JSON du réciteur, lecture AVFoundation d’un fichier local avec seek/pause/reprise, valeurs temporelles invalides et mini-player dans la zone de lecture.
- Le fichier audio silencieux des tests est généré uniquement pour les tests DEBUG ; il n’est jamais fourni comme contenu religieux ni inclus dans l’IPA Release.

Référence API : [AVPlayer, documentation Apple](https://developer.apple.com/documentation/avfoundation/avplayer).

Validation du complément audio : **21 tests unitaires + 4 tests UI réussis**, archive Release réussie, sur [GitHub Actions 37193061557](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37193061557). Le test UI déplace le curseur vers 30 secondes dans un fichier local de 60 secondes, vérifie le centrage horizontal et le retour à la hauteur initiale après réduction du mini-player.
