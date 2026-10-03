# Lecteur natif — intégration progressive

## Existant conservé

Le dépôt Swift, le projet Xcode, l’authentification Supabase, la session Keychain, le cache par compte, les thèmes, l’accueil et les cinq onglets ont été complétés. Le dépôt Expo / React Native n’est pas modifié. Le même Supabase est utilisé sans migration de schéma.

## Ressources exactes

- **Coran de Médine**, identifiant partagé `traditional` : les 604 PNG originaux de `assets/mushaf/page001.png` à `page604.png`, copiés sans modification. Environ 112,7 Mio de ressources compressées, disponibles hors connexion dès l’installation.
- **Coran 1441**, identifiant partagé `coran_1441` : archive `https://files.quran.app/hafs/madani_1441/zips/images_1440.zip`. Téléchargement uniquement lors de sa sélection. Extraction de 604 × 15 images dans Application Support. Canvas original 1440 × 2320, lignes 1440 × 232 positionnées suivant le lecteur RN. Les numéros de versets utilisent les coordonnées du JSON original : le ZIP contient les lignes et le lecteur existant ajoute déjà ces numéros. Les données originales de coordonnées sont également conservées pour retrouver le premier verset de la page.
- Aucun ZIP test n’a été mélangé aux sources. Les futurs rendus peuvent être ajoutés à `QuranSource`.

## Architecture

`QuranReaderView` fournit les options et la barre d’actions. `QuranPager`, un `UIViewControllerRepresentable`, pilote `UIPageViewController` en transition scroll native avec ordre arabe. Chaque contrôleur affiche un `UIImageView` en `scaleAspectFit` : centrage horizontal et vertical dans la zone disponible, sans déformation ni scroll vertical. Le tap masque ou rétablit les commandes. La Safe Area et les éléments SwiftUI inférieurs déterminent la hauteur disponible.

`QuranPageCache` décode hors du thread principal et conserve au maximum trois pages décodées. Les contrôleurs de page partagent ces images. La page courante est publiée avant le préchargement des voisines. Le changement de source vérifie les fichiers et prépare la page avant de remplacer la source affichée ; une erreur conserve le lecteur et sa source précédente.

## Reprise / marque-pages / compatibilité

Les opérations natives utilisent `lastRead`, `reader.mushaf`, `bookmarks`, `sourcePages` et les identifiants globaux de verset existants. Une suppression de marque-page crée un `deletedAt`, compatible avec la fusion RN. Le JSON complet et ses champs inconnus sont préservés.

Les changements sont enregistrés atomiquement dans le cache du compte avec une file `readerOperations` locale. La synchronisation relit `user_state` puis applique uniquement ces opérations ; la mise à jour est conditionnée au `updated_at` lu pour détecter un changement concurrent. Les opérations confirmées sont retirées de la file. Une répétition après une interruption conserve le même résultat, les dates et les tombstones. La synchronisation reprend au retour du réseau / à la réouverture / à la sortie du lecteur. Si aucun état RN valide n’existe encore pour un nouveau compte, les changements restent locaux ; ils ne remplacent pas un programme par un état incomplet.

## Audio

AVFoundation : lecture, pause, précédent, suivant, enchaînement verset par verset et choix Husary / Alafasy / Minshawi / Ash-Shatri. Les URL et identifiants de versets correspondent aux sources existantes. Les MP3 téléchargés sont conservés dans le cache natif et peuvent être réécoutés hors connexion. Le mini-player observe son service audio séparément : il ne pilote pas le rendu des images. Répétitions avancées, sélection d’une plage, surlignage audio et enregistrement vocal restent à migrer.

## Vérification

Des tests vérifient la conservation des champs inconnus, les suppressions persistantes, la relecture des anciennes sauvegardes, les limites de page et un parcours de 20 pages avec cache limité à trois images. Un test UI effectue le parcours dans les deux sources, avec des images 1441 originales préparées avant lancement ; ces fichiers de test ne sont pas inclus dans l’IPA Release.

Les résultats Xcode, captures et mesures sont complétés après exécution. La mémoire totale, le CPU, le taux réel d’images et les conflits de gestes sur iPhone demandent une mesure sur appareil avec Instruments. Aucun chiffre de fluidité 120 Hz n’est déduit d’un simulateur.
