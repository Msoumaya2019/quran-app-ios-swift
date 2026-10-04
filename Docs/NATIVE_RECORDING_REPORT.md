# Enregistrement vocal natif

## Existant conservé

Le projet Swift existant, les deux lecteurs, l’audio, les thèmes et l’authentification sont conservés. React Native n’est pas modifié. Le contrat existant `recitations` et le bucket privé `recitations` sont réutilisés, sans migration Supabase.

## Interface

Dans le lecteur : **Enregistrer** ouvre une feuille native avec sourate et plage de versets. Le microphone est demandé seulement après **Commencer l’enregistrement**. L’audio du Coran est mis en pause avant l’ouverture. Après arrêt : réécoute, recommencer ou **Conserver la récitation**. La plage ne peut pas être changée pendant la capture ou après capture, afin de ne pas attribuer un essai à un autre passage.

**Plus → Mes récitations** affiche les récitations locales et les récitations Coran récupérées du compte existant. Un audio distant est téléchargé lors de la réécoute puis conservé localement. Les récitations d’invocations ne sont pas migrées dans cette étape.

Une interruption audio ou le passage en arrière-plan arrête la capture. Le brouillon peut être validé dans l’écran encore ouvert. Il n’est pas envoyé tant que l’utilisateur ne choisit pas de le conserver. Fermer un brouillon demande confirmation ; quitter l’écran supprime uniquement cet essai temporaire.

## Format et stockage

AVAudioRecorder : AAC mono 44,1 kHz, 64 kbit/s, conteneur `.m4a`, durée limitée à 30 minutes. Les fichiers validés et un index JSON sont conservés dans Application Support, dans un dossier distinct par UUID de compte. Ils sont protégés jusqu’au premier déverrouillage de l’appareil. L’index est écrit atomiquement. Aucune URI locale n’est envoyée à Supabase.

Les métadonnées reprennent les champs existants : `id`, `user_id`, `start_verse_id`, `end_verse_id`, `duration_ms`, `storage_path`, `created_at`, `recording_type=quran`. Le chemin distant est `userUUID/recordingUUID.m4a`, avec le type MIME `audio/mp4`.

## Synchronisation

Une récitation validée reste `synced=false` jusqu’à confirmation serveur. Sa sauvegarde locale ne dépend pas du réseau. La synchronisation reprend à la validation, à l’ouverture de l’application, au retour de connexion, au retour au premier plan et dans Mes récitations.

L’envoi conserve le même identifiant et le même chemin à chaque essai. Il n’écrase pas un objet Storage existant. Si l’envoi du fichier avait déjà réussi, une vérification d’existence permet de reprendre l’insertion des métadonnées. La table utilise un upsert avec `ignoreDuplicates`. Le fichier local reste présent après confirmation.

Les échecs conservent la récitation en attente. Une récitation refusée n’empêche pas les autres de se synchroniser. Une absence de réseau arrête la série d’envois jusqu’à la prochaine tentative. Les réponses d’un ancien compte ne peuvent pas remplacer la liste du compte actif.

## Fichiers

Ajoutés :
- Models/Recitation.swift
- Storage/RecitationStorage.swift
- Repositories/RecitationRepository.swift
- Services/RecitationLibrary.swift
- Services/VoiceRecorderService.swift
- Services/RecitationPlaybackService.swift
- Features/Quran/VoiceRecorderView.swift
- Features/Quran/RecitationsView.swift
- Tests/RecitationTests.swift

Modifiés : App/CoranNativeApp.swift, Features/Navigation/RootView.swift, Features/Quran/QuranReaderView.swift, Networking/SupabaseService.swift, Config/Info.plist, UITests/ReaderUITests.swift et les références du projet Xcode existant. Le délai total réseau permet les envois audio, sans attendre le réseau pour afficher l’interface.

## Vérifications et limites

Tests : stockage persistant et séparation des comptes, validation de passage, contrat JSON RN, refus microphone, annulation pendant la demande d’autorisation, arrêt/conservation d’un brouillon, échec réseau, échec des métadonnées après upload, reprise sans doublon, réponse après changement de compte, fichier refusé ne bloquant pas les autres et parcours UI enregistrer → conserver → retrouver hors ligne.

Les tests UI utilisent une capture silencieuse simulée en DEBUG, jamais dans l’IPA Release et jamais envoyée à Supabase. Ils vérifient le parcours et les fichiers locaux. La qualité réelle du microphone, les interruptions téléphoniques et l’envoi avec un vrai compte restent à vérifier sur iPhone. Validation [GitHub Actions 37195798206](https://github.com/Msoumaya2019/quran-app-ios-swift/actions/runs/37195798206) réussie sur simulateur iPhone 17 Pro Max : 31 tests unitaires et 5 tests d’interface, zéro échec. Archive IPA Release non signée produite. Les dix tests unitaires des récitations et le parcours UI de sauvegarde sont inclus. Le menu Mes récitations est placé en tête des options pour rester accessible sans défilement.

Restent à migrer : suppression distante avec ses règles existantes, corrections/commentaires administrateur, partage social, enregistrements d’invocations et reprise d’un brouillon après destruction du processus iOS. Une récitation validée, elle, est persistante et conservée hors ligne.

Références : [permission microphone Apple](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)), [upload Supabase Swift](https://supabase.com/docs/reference/swift/storage-from-upload).
