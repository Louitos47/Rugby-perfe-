-- Autoriser le staff (manager/entraîneur) à modifier et supprimer
-- les événements de son équipe.
-- À exécuter dans Supabase → SQL Editor.

create policy "staff update team events" on team_events
  for update using (
    exists (
      select 1 from team_members tm
      where tm.team_id = team_events.team_id
        and tm.user_id = auth.uid()
        and tm.role in ('manager', 'coach')
    )
  ) with check (
    exists (
      select 1 from team_members tm
      where tm.team_id = team_events.team_id
        and tm.user_id = auth.uid()
        and tm.role in ('manager', 'coach')
    )
  );

create policy "staff delete team events" on team_events
  for delete using (
    exists (
      select 1 from team_members tm
      where tm.team_id = team_events.team_id
        and tm.user_id = auth.uid()
        and tm.role in ('manager', 'coach')
    )
  );
