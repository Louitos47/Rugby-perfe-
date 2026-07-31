-- ════════════════════════════════════════════════════════════════════════
-- CONSENTEMENT RGPD À L'INSCRIPTION — traçabilité
-- Stocke, sur le profil du joueur : la date/heure du consentement, la version
-- des documents acceptés (CGU + Politique de confidentialité) et le consentement
-- explicite au traitement des données de santé.
-- À exécuter dans Supabase → SQL Editor. Non destructif (idempotent).
-- ════════════════════════════════════════════════════════════════════════

alter table profiles add column if not exists rgpd_consent_at timestamptz;
alter table profiles add column if not exists rgpd_cgu_version text;
alter table profiles add column if not exists rgpd_confidentialite_version text;
alter table profiles add column if not exists rgpd_medical_consent boolean default false;

-- Note : le consentement est AUSSI enregistré dans les métadonnées d'authentification
-- (auth.users.raw_user_meta_data : rgpd_consent_at, rgpd_cgu_version,
--  rgpd_confidentialite_version, rgpd_medical_consent) dès l'appel signUp(),
-- ce qui garantit la capture même si la confirmation email est activée.
-- Les colonnes ci-dessus reçoivent la même information côté profil, applicable
-- immédiatement (confirmation email désactivée) ou au premier login (confirmation
-- activée), pour disposer d'une preuve lisible directement dans la table profiles.
