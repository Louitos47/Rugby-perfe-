-- ════════════════════════════════════════════════════════════════════════
-- CONFIDENTIALITÉ DES DONNÉES MÉDICALES
-- Modèle : kiné = accès complet · manager = aptitude + type + durée seulement
--          coéquipiers = rien · chaque joueur = ses propres données
-- À exécuter dans Supabase → SQL Editor. Idempotent (drop policy if exists).
-- ════════════════════════════════════════════════════════════════════════

-- ── 0. DIAGNOSTIC : lister les policies réellement en place avant de changer
-- (Exécute ce SELECT seul d'abord pour voir l'état actuel, puis le reste.)
--   select tablename, policyname, cmd, roles, qual, with_check
--   from pg_policies
--   where tablename in ('injuries','player_injury_log','medical_files','kine_session_notes')
--   order by tablename, cmd;


-- ── 1. INJURIES ───────────────────────────────────────────────────────────
-- On RETIRE l'accès direct large du staff non-médical : cette policy exposait
-- TOUTES les colonnes (dont les notes cliniques) au manager/prépa/coach.
drop policy if exists "staff reads team injuries" on injuries;

-- Le joueur garde l'accès total à SES blessures (déclaration, lecture, maj)
drop policy if exists "user manages own injuries" on injuries;
create policy "user manages own injuries" on injuries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- (Les policies "kine reads/inserts/updates team injuries" de kine_powers.sql
--  restent en place : le staff médical conserve son accès complet.)


-- ── 2. VUE MANAGER RESTREINTE ─────────────────────────────────────────────
-- Le manager (et l'entraîneur, qui partage l'interface manager) ne peut lire
-- QUE les colonnes utiles à la gestion d'équipe, jamais les notes.
-- Vue en security definer (par défaut) : elle lit injuries en contournant sa
-- RLS, mais n'expose que ces colonnes et seulement pour les joueurs de l'équipe
-- du demandeur.
drop view if exists manager_injury_view;
create view manager_injury_view as
select
  i.id,
  i.user_id,
  i.type,
  i.duree_estimee_jours,
  i.statut,
  i.apte_au_jeu,
  i.date_debut
from injuries i
where exists (
  select 1
  from team_members mgr
  join team_members p on p.team_id = mgr.team_id and p.user_id = i.user_id
  where mgr.user_id = auth.uid()
    and mgr.role in ('manager', 'coach')  -- ← ajoute 'prepa' ici si tu veux que le prépa voie aussi le type de blessure
);

grant select on manager_injury_view to authenticated;


-- ── 3. KINE_SESSION_NOTES : strictement réservé au staff médical ───────────
alter table kine_session_notes enable row level security;

drop policy if exists "kine manages team notes" on kine_session_notes;
create policy "kine manages team notes" on kine_session_notes
  for all using (
    kine_id = auth.uid()
    or exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = kine_session_notes.player_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  ) with check (
    kine_id = auth.uid()
    or exists (
      select 1 from team_members k
      join team_members p on p.team_id = k.team_id and p.user_id = kine_session_notes.player_id
      where k.user_id = auth.uid() and k.role = 'kine'
    )
  );
-- (Aucune policy pour joueur/manager : les notes du kiné leur sont invisibles.)


-- ── 4. PLAYER_INJURY_LOG : journal perso du joueur, à lui seul ─────────────
alter table player_injury_log enable row level security;

drop policy if exists "user manages own injury log" on player_injury_log;
create policy "user manages own injury log" on player_injury_log
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());


-- ── 5. MEDICAL_FILES : déjà correct (joueur + staff médical uniquement) ────
-- Rien à changer : la policy "player or medical read files" n'inclut PAS le
-- manager. Vérifie juste qu'aucune autre policy plus large n'a été ajoutée :
--   select policyname, qual from pg_policies where tablename = 'medical_files';
