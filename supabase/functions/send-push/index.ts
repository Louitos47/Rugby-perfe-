// Edge Function : envoi de notifications push OneSignal aux joueurs d'une équipe.
// La clé REST OneSignal reste ici, côté serveur (secret ONESIGNAL_API_KEY) —
// elle ne doit JAMAIS apparaître dans le code client (index.html).
//
// Deux modes :
//   - Équipe entière (annonces, rapports, événements) : réservé au staff
//     { "team_id": 12, "title": "📣 Mon équipe", "message": "RDV 10h dimanche" }
//   - Message privé (recipient_id) : tout membre peut notifier un autre membre
//     { "team_id": 12, "recipient_id": "uuid", "title": "✉️ Louis", "message": "Salut !" }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const ONESIGNAL_APP_ID = 'c2879730-8d3b-42fe-b7cd-b87968aa109f';
const APP_URL = 'https://meek-kheer-0fc106.netlify.app';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { team_id, title, message, recipient_id } = await req.json();
    if (!team_id || !message) return json({ error: 'team_id et message requis' }, 400);

    // 1. Authentifier l'appelant via son JWT
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: 'Non authentifié' }, 401);

    // 2. Vérifier l'appartenance à l'équipe (un compte peut cumuler plusieurs rôles)
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: memberships } = await admin
      .from('team_members')
      .select('role')
      .eq('team_id', team_id)
      .eq('user_id', user.id);
    const roles = (memberships ?? []).map((m) => m.role);
    if (!roles.length) return json({ error: "Réservé aux membres de l'équipe" }, 403);

    if (recipient_id) {
      // Message privé : le destinataire doit être membre de la même équipe
      const { data: rec } = await admin
        .from('team_members')
        .select('user_id')
        .eq('team_id', team_id)
        .eq('user_id', recipient_id)
        .limit(1);
      if (!rec?.length) return json({ error: "Destinataire hors équipe" }, 403);
    } else if (!roles.some((r) => ['manager', 'prepa', 'coach'].includes(r))) {
      // Notification à toute l'équipe : réservé au staff
      return json({ error: "Réservé au staff de l'équipe" }, 403);
    }

    // 3. Construire et envoyer la notification
    const payload: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { fr: title || '📣 Rugby Perf', en: title || '📣 Rugby Perf' },
      contents: { fr: message, en: message },
      url: APP_URL,
    };
    if (recipient_id) {
      payload.include_aliases = { external_id: [String(recipient_id)] };
      payload.target_channel = 'push';
    } else {
      payload.filters = [{ field: 'tag', key: 'team_id', relation: '=', value: String(team_id) }];
    }

    const resp = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + Deno.env.get('ONESIGNAL_API_KEY'),
      },
      body: JSON.stringify(payload),
    });
    const result = await resp.json();
    return json({ ok: resp.ok, result }, resp.ok ? 200 : 502);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
