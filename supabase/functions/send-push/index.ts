// Edge Function : envoi de notifications push OneSignal.
// La clé REST OneSignal reste ici, côté serveur (secret ONESIGNAL_API_KEY).
//
// Modes :
//   - Équipe entière (annonces, rapports, événements) : réservé au staff
//     { "team_id": 12, "title": "📣 ...", "message": "..." }
//   - Chat d'équipe (chat: true) : tout membre peut notifier l'équipe
//     { "team_id": 12, "title": "💬 ...", "message": "...", "chat": true }
//   - Ciblé (message privé ou groupe) : tout membre → membres de la même équipe
//     { "team_id": 12, "recipient_id": "uuid", ... }
//     { "team_id": 12, "recipient_ids": ["uuid", ...], ... }

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
    const body = await req.json();
    // Ping de version : permet à l'app de savoir si cette fonction est à jour
    if (body.ping) return json({ ok: true, version: 2 });
    const { team_id, title, message, recipient_id, recipient_ids, chat, send_after, players_only } = body;
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

    // 3. Déterminer la cible
    const payload: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { fr: title || '📣 Rugby Perf', en: title || '📣 Rugby Perf' },
      contents: { fr: message, en: message },
      url: APP_URL,
    };
    // Notification programmée (ex: check-in "pas de bobo ?" le soir du match)
    if (send_after) payload.send_after = send_after;

    const targets: string[] = recipient_ids?.length
      ? recipient_ids
      : (recipient_id ? [recipient_id] : []);

    if (targets.length) {
      // Ciblé : tous les destinataires doivent être membres de la même équipe
      const { data: recs } = await admin
        .from('team_members')
        .select('user_id')
        .eq('team_id', team_id)
        .in('user_id', targets);
      const valid = new Set((recs ?? []).map((r) => r.user_id));
      const finalTargets = targets.filter((t) => valid.has(t));
      if (!finalTargets.length) return json({ error: 'Destinataires hors équipe' }, 403);
      payload.include_aliases = { external_id: finalTargets.map(String) };
      payload.target_channel = 'push';
    } else if (chat === true) {
      // Message de chat d'équipe : tout membre peut notifier l'équipe
      payload.filters = [{ field: 'tag', key: 'team_id', relation: '=', value: String(team_id) }];
      // Cibler uniquement les joueurs (ex: check-in "pas de bobo ?")
      if (players_only) {
        (payload.filters as unknown[]).push({ field: 'tag', key: 'role', relation: '=', value: 'joueur' });
      }
    } else if (roles.some((r) => ['manager', 'prepa', 'coach'].includes(r))) {
      // Notification officielle à toute l'équipe : réservé au staff
      payload.filters = [{ field: 'tag', key: 'team_id', relation: '=', value: String(team_id) }];
      // Cibler uniquement les joueurs (ex: check-in "pas de bobo ?")
      if (players_only) {
        (payload.filters as unknown[]).push({ field: 'tag', key: 'role', relation: '=', value: 'joueur' });
      }
    } else {
      return json({ error: "Réservé au staff de l'équipe" }, 403);
    }

    // 4. Envoyer
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
