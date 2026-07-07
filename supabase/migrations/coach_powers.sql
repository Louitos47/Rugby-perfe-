-- Pouvoirs de l'entraîneur (coach) : même interface que le manager,
-- à l'exception des liens d'invitation d'équipe.
-- À exécuter dans Supabase → SQL Editor.
-- Si une ligne échoue avec "policy already exists", supprime juste cette ligne et relance.

-- Lire les bilans des joueurs sur les événements (partie Stats)
create policy "coach reads event bilans" on team_event_bilans
  for select using (
    exists (
      select 1 from team_events e
      join team_members c on c.team_id = e.team_id and c.user_id = auth.uid() and c.role = 'coach'
      where e.id = team_event_bilans.team_event_id
    )
  );

-- Créer des événements d'équipe (matchs / entraînements)
create policy "coach inserts team events" on team_events
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = team_events.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );

-- Publier des annonces
create policy "coach inserts announcements" on team_announcements
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = team_announcements.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );

-- Publier des documents projet de jeu
create policy "coach inserts documents" on team_documents
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = team_documents.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );
create policy "coach deletes own documents" on team_documents
  for delete using (created_by = auth.uid());

-- Publier des analyses adverses
create policy "coach inserts analyses" on team_opponent_analysis
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = team_opponent_analysis.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );
create policy "coach deletes own analyses" on team_opponent_analysis
  for delete using (created_by = auth.uid());

-- Débriefs d'équipe (lecture + création)
create policy "coach reads debriefs" on team_debriefs
  for select using (
    exists (
      select 1 from team_members c
      where c.team_id = team_debriefs.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );
create policy "coach inserts debriefs" on team_debriefs
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = team_debriefs.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );

-- Stats de match (lecture + saisie)
create policy "coach reads match stats" on match_stats
  for select using (
    exists (
      select 1 from team_members c
      where c.team_id = match_stats.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );
create policy "coach inserts match stats" on match_stats
  for insert with check (
    exists (
      select 1 from team_members c
      where c.team_id = match_stats.team_id and c.user_id = auth.uid() and c.role = 'coach'
    )
  );
