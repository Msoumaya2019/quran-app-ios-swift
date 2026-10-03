# Analyse du backend existant

Projet Supabase : `npbwnvrqmajwqtnncuyv`. Analyse des migrations du commit RN `f538ae3`, sans modification.

## Limite de la vérification

La clé publique ne permet pas de consulter les catalogues privés, paramètres Auth, secrets, déploiements Edge Functions ou configurations APNs. Cette carte décrit les objets déclarés dans le dépôt ; elle ne prétend pas être un dump de production. Aucun accès administrateur n’a été demandé et aucune migration n’est nécessaire en phase 1.

## function

| Objet | Migration |
|---|---|
| `public.open_admin_contact` | `supabase/admin-contact.sql` |
| `private.sync_admin_contacts` | `supabase/admin-contact.sql` |
| `public.admin_learning_accounts` | `supabase/admin-learning-accounts.sql` |
| `public.admin_notification_recipients` | `supabase/admin-notifications.sql` |
| `public.send_admin_notification` | `supabase/admin-notifications.sql` |
| `public.daily_content_for_date` | `supabase/daily-contents.sql` |
| `private.validate_invocation_recording` | `supabase/daily-contents.sql` |
| `private.can_play_shared_recitation` | `supabase/daily-contents.sql` |
| `public.save_daily_content` | `supabase/daily-contents.sql` |
| `private.notify_private_message` | `supabase/fix-social-push.sql` |
| `public.friend_inbox` | `supabase/friend-inbox.sql` |
| `private.friend_room_access` | `supabase/friend-realtime.sql` |
| `private.notify_recitation_corrected` | `supabase/notification-corrections.sql` |
| `public.finalize_recitation_correction` | `supabase/notification-corrections.sql` |
| `private.notify_private_message` | `supabase/notifications.sql` |
| `private.send_expo_push` | `supabase/push-delivery-monitor.sql` |
| `private.collect_push_receipts` | `supabase/push-delivery-monitor.sql` |
| `public.my_push_delivery_status` | `supabase/push-delivery-monitor.sql` |
| `public.register_push_device` | `supabase/push-device-registration.sql` |
| `private.quiz_push` | `supabase/quiz-notifications.sql` |
| `private.quiz_challenge_notification` | `supabase/quiz-notifications.sql` |
| `public.quiz_set_notifications` | `supabase/quiz-notifications.sql` |
| `private.quiz_notify_daily` | `supabase/quiz-notifications.sql` |
| `private.quiz_question_json` | `supabase/quiz.sql` |
| `private.quiz_public_question` | `supabase/quiz.sql` |
| `public.quiz_answer_daily` | `supabase/quiz.sql` |
| `public.quiz_create_challenge` | `supabase/quiz.sql` |
| `public.quiz_answer_challenge` | `supabase/quiz.sql` |
| `public.quiz_snapshot` | `supabase/quiz.sql` |
| `public.quiz_admin_list` | `supabase/quiz.sql` |
| `public.quiz_admin_save` | `supabase/quiz.sql` |
| `public.quiz_admin_delete` | `supabase/quiz.sql` |
| `public.quiz_admin_sets` | `supabase/quiz.sql` |
| `public.quiz_admin_save_set` | `supabase/quiz.sql` |
| `public.quiz_admin_delete_set` | `supabase/quiz.sql` |
| `private.validate_recitation_message` | `supabase/recitation-sharing.sql` |
| `private.can_play_shared_recitation` | `supabase/recitation-sharing.sql` |
| `public.friend_overview` | `supabase/social-v2.sql` |
| `public.my_unread_messages` | `supabase/social-v2.sql` |
| `private.notify_private_message` | `supabase/social-v2.sql` |
| `private.notify_friend_link` | `supabase/social-v2.sql` |
| `private.is_friend` | `supabase/social.sql` |
| `private.is_app_admin` | `supabase/social.sql` |
| `private.is_social_suspended` | `supabase/social.sql` |
| `private.has_friend_link` | `supabase/social.sql` |
| `private.active_link` | `supabase/social.sql` |
| `private.group_member` | `supabase/social.sql` |
| `private.group_invitee` | `supabase/social.sql` |
| `private.group_moderator` | `supabase/social.sql` |
| `private.shared_group` | `supabase/social.sql` |
| `private.can_read_chat` | `supabase/social.sql` |
| `public.ensure_social_profile` | `supabase/social.sql` |
| `public.request_friend` | `supabase/social.sql` |
| `public.accept_friend` | `supabase/social.sql` |
| `public.decline_friend` | `supabase/social.sql` |
| `public.remove_friend` | `supabase/social.sql` |
| `public.block_friend` | `supabase/social.sql` |
| `public.unblock_friend` | `supabase/social.sql` |
| `public.publish_social_progress` | `supabase/social.sql` |
| `public.set_social_online` | `supabase/social.sql` |
| `public.friend_overview` | `supabase/social.sql` |
| `public.create_friend_group` | `supabase/social.sql` |
| `public.invite_group_member` | `supabase/social.sql` |
| `public.accept_group_invite` | `supabase/social.sql` |
| `public.decline_group_invite` | `supabase/social.sql` |
| `public.set_group_moderator` | `supabase/social.sql` |
| `public.remove_group_member` | `supabase/social.sql` |
| `public.delete_friend_group` | `supabase/social.sql` |
| `public.delete_friend_message` | `supabase/social.sql` |
| `public.resolve_friend_report` | `supabase/social.sql` |
| `public.suspend_social_member` | `supabase/social.sql` |
| `public.unsuspend_social_member` | `supabase/social.sql` |
| `public.report_friend_message` | `supabase/social.sql` |
| `public.accept_shared_goal` | `supabase/social.sql` |
| `public.accept_review_appointment` | `supabase/social.sql` |
| `public.cancel_review_appointment` | `supabase/social.sql` |

## trigger

| Objet | Migration |
|---|---|
| `sync_admin_contacts` | `supabase/admin-contact.sql` |
| `validate_invocation_recording` | `supabase/daily-contents.sql` |
| `notify_recitation_corrected` | `supabase/notification-corrections.sql` |
| `notify_private_message` | `supabase/notifications.sql` |
| `quiz_challenge_push` | `supabase/quiz-notifications.sql` |
| `quiz_answer_push` | `supabase/quiz-notifications.sql` |
| `validate_recitation_message` | `supabase/recitation-sharing.sql` |
| `notify_friend_link` | `supabase/social-v2.sql` |

## table

| Objet | Migration |
|---|---|
| `public.admin_notifications` | `supabase/admin-notifications.sql` |
| `public.content_categories` | `supabase/daily-contents.sql` |
| `public.daily_contents` | `supabase/daily-contents.sql` |
| `public.daily_content_schedule` | `supabase/daily-contents.sql` |
| `public.content_favorites` | `supabase/daily-contents.sql` |
| `public.notification_preferences` | `supabase/notifications.sql` |
| `public.push_devices` | `supabase/notifications.sql` |
| `public.app_problem_reports` | `supabase/problem-reports.sql` |
| `private.push_delivery_log` | `supabase/push-delivery-monitor.sql` |
| `private.quiz_notification_events` | `supabase/quiz-notifications.sql` |
| `public.quiz_questions` | `supabase/quiz.sql` |
| `public.quiz_daily_responses` | `supabase/quiz.sql` |
| `public.quiz_challenges` | `supabase/quiz.sql` |
| `public.quiz_challenge_questions` | `supabase/quiz.sql` |
| `public.quiz_challenge_answers` | `supabase/quiz.sql` |
| `public.quiz_sets` | `supabase/quiz.sql` |
| `public.recitations` | `supabase/recitations.sql` |
| `public.recitation_corrections` | `supabase/recitations.sql` |
| `public.recitation_feedback` | `supabase/recitations.sql` |
| `public.user_state` | `supabase/schema.sql` |
| `public.friend_message_reads` | `supabase/social-v2.sql` |
| `public.friend_message_hidden` | `supabase/social-v2.sql` |
| `public.friend_profiles` | `supabase/social.sql` |
| `public.friend_links` | `supabase/social.sql` |
| `public.friend_progress` | `supabase/social.sql` |
| `public.friend_groups` | `supabase/social.sql` |
| `public.friend_group_members` | `supabase/social.sql` |
| `public.friend_messages` | `supabase/social.sql` |
| `public.friend_message_reports` | `supabase/social.sql` |
| `public.app_admins` | `supabase/social.sql` |
| `public.social_suspensions` | `supabase/social.sql` |
| `public.friend_shared_goals` | `supabase/social.sql` |
| `public.friend_review_appointments` | `supabase/social.sql` |

## policy

| Objet | Migration |
|---|---|
| `admin_notifications_read` | `supabase/admin-notifications.sql` |
| `daily_media_admin` | `supabase/daily-content-media.sql` |
| `daily_media_active_read` | `supabase/daily-content-media.sql` |
| `categories_read` | `supabase/daily-contents.sql` |
| `categories_read_public` | `supabase/daily-contents.sql` |
| `categories_admin` | `supabase/daily-contents.sql` |
| `contents_read` | `supabase/daily-contents.sql` |
| `contents_read_public` | `supabase/daily-contents.sql` |
| `contents_admin` | `supabase/daily-contents.sql` |
| `schedule_read` | `supabase/daily-contents.sql` |
| `schedule_admin` | `supabase/daily-contents.sql` |
| `favorites_own` | `supabase/daily-contents.sql` |
| `friend_avatars_read` | `supabase/friend-avatars.sql` |
| `friend_avatars_insert` | `supabase/friend-avatars.sql` |
| `friend_avatars_update` | `supabase/friend-avatars.sql` |
| `friend_avatars_delete` | `supabase/friend-avatars.sql` |
| `friend_read_receipts` | `supabase/friend-avatars.sql` |
| `friend_room_receive` | `supabase/friend-realtime.sql` |
| `friend_room_send` | `supabase/friend-realtime.sql` |
| `notification settings own` | `supabase/notifications.sql` |
| `push devices own` | `supabase/notifications.sql` |
| `problem_reports_read` | `supabase/problem-reports.sql` |
| `problem_reports_insert` | `supabase/problem-reports.sql` |
| `problem_reports_admin_update` | `supabase/problem-reports.sql` |
| `problem_screenshots_insert` | `supabase/problem-reports.sql` |
| `problem_screenshots_read` | `supabase/problem-reports.sql` |
| `quiz_admin` | `supabase/quiz.sql` |
| `quiz_daily_own` | `supabase/quiz.sql` |
| `quiz_challenge_member` | `supabase/quiz.sql` |
| `quiz_answer_own` | `supabase/quiz.sql` |
| `quiz_question_member` | `supabase/quiz.sql` |
| `recitations_read` | `supabase/recitation-sharing.sql` |
| `recitation_files_read` | `supabase/recitation-sharing.sql` |
| `recitations_owner_delete` | `supabase/recitation-sharing.sql` |
| `recitation_files_owner_delete` | `supabase/recitation-sharing.sql` |
| `recitations_read` | `supabase/recitations.sql` |
| `recitations_insert` | `supabase/recitations.sql` |
| `recitations_update` | `supabase/recitations.sql` |
| `corrections_read` | `supabase/recitations.sql` |
| `corrections_admin_insert` | `supabase/recitations.sql` |
| `corrections_admin_update` | `supabase/recitations.sql` |
| `feedback_read` | `supabase/recitations.sql` |
| `feedback_admin_insert` | `supabase/recitations.sql` |
| `recitation_files_owner_insert` | `supabase/recitations.sql` |
| `recitation_files_read` | `supabase/recitations.sql` |
| `recitation_feedback_admin_insert` | `supabase/recitations.sql` |
| `own state select` | `supabase/schema.sql` |
| `own state insert` | `supabase/schema.sql` |
| `own state update` | `supabase/schema.sql` |
| `own state delete` | `supabase/schema.sql` |
| `own message reads` | `supabase/social-v2.sql` |
| `own hidden messages` | `supabase/social-v2.sql` |
| `profiles read` | `supabase/social.sql` |
| `profiles insert` | `supabase/social.sql` |
| `profiles update` | `supabase/social.sql` |
| `links read` | `supabase/social.sql` |
| `progress own read` | `supabase/social.sql` |
| `progress own insert` | `supabase/social.sql` |
| `progress own update` | `supabase/social.sql` |
| `groups read` | `supabase/social.sql` |
| `group members read` | `supabase/social.sql` |
| `chat read` | `supabase/social.sql` |
| `chat send` | `supabase/social.sql` |
| `reports own read` | `supabase/social.sql` |
| `reports moderators read` | `supabase/social.sql` |
| `reports admins read` | `supabase/social.sql` |
| `admins own read` | `supabase/social.sql` |
| `suspensions read` | `supabase/social.sql` |
| `shared goals read` | `supabase/social.sql` |
| `shared goals propose` | `supabase/social.sql` |
| `appointments read` | `supabase/social.sql` |
| `appointments propose` | `supabase/social.sql` |

## Appels par service

| Source React Native | Tables | RPC |
|---|---|---|
| `src\services\adminAccounts.ts` |  | admin_learning_accounts |
| `src\services\adminNotifications.ts` | admin_notifications | admin_notification_recipients, send_admin_notification |
| `src\services\audioFocus.ts` |  |  |
| `src\services\authStorage.ts` |  |  |
| `src\services\avatars.ts` | friend_profiles | ensure_social_profile |
| `src\services\connectivity.ts` |  |  |
| `src\services\dailyContentMedia.ts` | daily_contents |  |
| `src\services\dailyContents.ts` | content_categories, content_favorites, daily_content_schedule, daily_contents | daily_content_for_date, save_daily_content |
| `src\services\notifications.ts` | notification_preferences, push_devices | my_push_delivery_status, register_push_device |
| `src\services\offlineSync.ts` |  |  |
| `src\services\problemReports.ts` | app_problem_reports |  |
| `src\services\quiz.ts` |  |  |
| `src\services\quranAudioTimeline.ts` |  |  |
| `src\services\quranDownload.ts` |  |  |
| `src\services\quranSourceReady.ts` |  |  |
| `src\services\recitations.ts` | recitation_corrections, recitation_feedback, recitations | finalize_recitation_correction |
| `src\services\social.ts` | app_admins, friend_group_members, friend_groups, friend_links, friend_message_hidden, friend_message_reads, friend_message_reports, friend_messages, friend_profiles, friend_review_appointments, friend_shared_goals, recitations, social_suspensions | accept_friend, accept_group_invite, accept_review_appointment, accept_shared_goal, block_friend, cancel_review_appointment, create_friend_group, decline_friend, decline_group_invite, delete_friend_group, delete_friend_message, ensure_social_profile, friend_inbox, friend_overview, invite_group_member, my_unread_messages, open_admin_contact, publish_social_progress, remove_friend, remove_group_member, report_friend_message, request_friend, resolve_friend_report, set_group_moderator, set_social_online, suspend_social_member, unblock_friend, unsuspend_social_member |
| `src\services\storage.ts` |  |  |
| `src\services\sync.ts` | user_state |  |
| `src\services\verseAudioCache.ts` |  |  |

## Contrat de compatibilité

`user_state.data` porte schema=1, knowledge, goal, pace, sessions, revisions, studyProgress, reviewConsolidations, reviewCycle, histories, bookmarks et préférences. Les IDs de versets sont globaux 1…6236. scheduledDate reste indépendante de completedAt. Les valeurs de statut RN sont todo/done/postponed. La phase 1 Swift lit le JSON complet, conserve les champs inconnus dans le cache et ne fait aucun upsert de user_state. Les quiz utilisent des RPC côté serveur et ne doivent pas divulguer de solution avant la fin du défi. Les captures et récitations privées doivent utiliser les politiques et URLs signées existantes.

## Notifications

Le backend actuel délivre des pushes Expo. Un token APNs natif ne doit pas être inséré comme token Expo. L’adaptateur APNs sera une extension additive en phase 4 après configuration Apple ; aucune table de push ni trigger existant n’est modifié.

## Sources Quran

Le code actuel conserve traditional, tajweed, coranTest (Médine) et coran_1441. Les anciens identifiants tawjeed_test_2/tajweed_test_2/medine_test sont migrés vers coran_1441 par RN. La demande Swift les mentionne à nouveau : à arbitrer avant la phase 2, aucun lecteur ou ZIP n’est intégré en phase 1.
