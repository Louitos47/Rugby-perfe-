-- Pouvoirs du kiné : voir/déclarer/mettre à jour les blessures des joueurs
-- de ses équipes, et changer leur aptitude au jeu.
-- À exécuter dans Supabase → SQL Editor.

-- Le kiné voit les blessures des joueurs de ses équipes
create policy "kine reads team injuries" on injuries
  for select using (
    exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = injuries.user_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  );

-- Le kiné déclare une blessure pour un joueur de ses équipes
create policy "kine inserts team injuries" on injuries
  for insert with check (
    exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = injuries.user_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  );

-- Le kiné met à jour ces blessures (statut, guérison...)
create policy "kine updates team injuries" on injuries
  for update using (
    exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = injuries.user_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  ) with check (
    exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = injuries.user_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  );

-- Le kiné peut modifier l'aptitude au jeu des membres de ses équipes
create policy "kine updates team aptitude" on team_members
  for update using (
    exists (
      select 1 from team_members k
      where k.team_id = team_members.team_id
        and k.user_id = auth.uid()
        and k.role = 'kine'
    )
  ) with check (
    exists (
      select 1 from team_members k
      where k.team_id = team_members.team_id
        and k.user_id = auth.uid()
        and k.role = 'kine'
    )
  );
