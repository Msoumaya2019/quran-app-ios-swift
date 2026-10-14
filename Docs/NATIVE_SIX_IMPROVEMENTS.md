# Six améliorations natives — 14 octobre 2026

## Changements

- Réglages : suppression des blocs Tajweed dupliqués et de Version native ; les trois sources restent sélectionnables. Téléchargement/cache Tajweed conservés dans Téléchargements et sources.
- Profil : avatar ouvre Mon profil ; roue dentée ouvre Réglages. Nom affiché/photo/visibilité réutilisent friend_profiles et FriendsLibrary, sans deuxième profil. Le modèle actuel contient un nom affiché, pas des champs prénom/nom séparés. Progression issue de knowledge ; objectif et récitations existants.
- Apparence : Clair/Sombre/Automatique, persistés dans native.appearance ; couleurs adaptatives des composants et contrôles système. Images monochromes : papier sombre/encre ivoire sans changement géométrique ; couleurs saturées préservées. Tajweed utilise palette COLRv1 1, Basmala également ; cadre redessiné seulement en couleur depuis son alpha original. Aucun téléchargement supplémentaire de police sombre.
- 1441 : la chaîne des chiffres était encodée incorrectement. Conversion explicite de chiffres canoniques par scalaires U+0660…U+0669 ; mêmes coordonnées originales. Les 6236 marqueurs sont uniques et canoniques ; page 600 comprend Al-Adiyat 6–11, Al-Qariah 1–11, At-Takathur 1–8.
- Activité : collecte inactive par défaut. Le serveur et la participation de l’utilisateur doivent tous deux l’autoriser. Temps monotone au premier plan, checkpoints locaux toutes les 10 s, envois groupés chaque minute/au départ ; aucune reprise de temps pendant la fermeture. Une fermeture brutale peut perdre au maximum le dernier intervalle de 10 s. File locale protégée, propriétaire distinct, conservation 30 jours, plafond 1000 intervalles. RPC idempotente par utilisateur+intervalle ; aucun contenu, écran, appareil ou IP collecté par cette fonctionnalité.

## Backend à appliquer manuellement

1. Appliquer `Supabase/native-activity.sql` dans le projet Supabase existant. Aucune table/policy existante n’est supprimée ou renommée.
2. Définir native_activity_settings.admin_user_id avec l’UUID réel du propriétaire qui figure déjà dans app_admins. Pas d’UUID déduit ou injecté automatiquement. Seul cet administrateur lit les résumés ; les autres administrateurs sont refusés.
3. Faire valider par le responsable du traitement la base légale, l’information/politique de confidentialité, les droits et la durée de conservation. L’écran donne une information et une participation facultative, mais ne remplace pas cette validation RGPD.
4. Configurer une exécution quotidienne côté serveur de `select public.native_activity_purge();` (rôle service_role ou propriétaire DB), puis vérifier la tâche. Elle ne purge que les nouvelles données de suivi âgées de plus de 30 jours.
5. Après ces validations, renseigner legal_review_confirmed et retention_job_confirmed, puis enabled=true. Le consentement utilisateur reste nécessaire. Sans cette étape aucune collecte ne démarre.
6. Vérifier le refus avec un vrai JWT membre et un JWT d’un autre admin sur la production. Les tests PostgreSQL isolés couvrent la sécurité des fonctions ; ils ne prouvent pas l’état déployé de votre projet.

La dernière authentification provient exclusivement de auth.users.last_sign_in_at (événement Supabase, pas présence au premier plan). Les périodes utilisent le fuseau local demandé ; 7 jours calendaires incluent aujourd’hui. Temps d’utilisation limité aux personnes participantes et à l’app native, pas des statistiques fictives historiques de React Native.

## Validation

Tests Swift : tous les marqueurs 1441, conversion des chiffres, temps premier plan sans arrière-plan, transformations de pixels, persistance du mode sombre. Tests WebKit et UI de navigation existants/ajoutés. Résultats Xcode à consigner après exécution. Pas de Xcode ni d’iPhone physique sur cet environnement Windows.

Tests SQL en base PostgreSQL jetable : collecte désactivée, refus membre/autre administrateur/anonyme, refus tables brutes, double synchronisation, retrait de participation et absence de fausse authentification. Aucun secret ni compte réel utilisé.

Retrait de participation hors ligne : arrêt local immédiat, purge locale et demande d’effacement serveur conservée jusqu’au retour de connexion. Les données déjà envoyées ne peuvent être effacées du serveur sans réseau.

Au démarrage hors ligne, une autorisation serveur précédemment confirmée et la participation confirmée sont utilisables pendant 24 h au maximum. Après ce délai, aucun nouveau suivi ne démarre avant vérification serveur. Les sessions sont des passages au premier plan avec du temps actif mesuré, pas des connexions.
