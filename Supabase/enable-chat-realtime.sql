-- Facultatif : activer les événements des messages si la table n'est pas déjà publiée.
-- À exécuter dans le SQL Editor Supabase. Ne change aucune table, donnée ou policy.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RAISE EXCEPTION 'Publication supabase_realtime absente : activer Realtime dans le projet.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'friend_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_messages;
  END IF;
END $$;
