-- Objectif de reprise des blessures (renseigné par le staff médical).
-- À exécuter dans Supabase → SQL Editor. Non destructif.

alter table injuries add column if not exists date_reprise_prevue date;
alter table injuries add column if not exists objectif_reprise text;
