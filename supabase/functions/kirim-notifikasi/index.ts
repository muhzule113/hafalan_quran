import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const supabaseUrl = Deno.env.get('SB_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SB_SERVICE_KEY') ?? '';
    const { setoran_id, santri_id, ustadz_nama, surah, ayat_mulai, ayat_selesai } = await req.json();
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    // Cari orang tua dari santri
    const { data: santri } = await supabase.from('santri').select('nama, orang_tua_id').eq('id', santri_id).single();
    if (!santri?.orang_tua_id) {
      return new Response(JSON.stringify({
        message: 'Santri belum terhubung ke orang tua'
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Ambil FCM token orang tua
    const { data: orangTua } = await supabase.from('profiles').select('nama, fcm_token').eq('id', santri.orang_tua_id).single();
    const judul = `Setoran Hafalan ${santri.nama}`;
    const pesan = `${santri.nama} baru saja menyetor ${surah} ayat ${ayat_mulai}-${ayat_selesai} kepada ${ustadz_nama}`;
    // Simpan ke tabel notifikasi
    await supabase.from('notifikasi').insert({
      orang_tua_id: santri.orang_tua_id,
      santri_id,
      setoran_id,
      judul,
      pesan
    });
    // Kirim FCM jika ada token & Firebase config
    const fcmServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (orangTua?.fcm_token && fcmServiceAccount) {
      try {
        const serviceAccount = JSON.parse(fcmServiceAccount);
        const projectId = serviceAccount.project_id;
        // Get access token
        const tokenRes = await fetch(`https://oauth2.googleapis.com/token`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: new URLSearchParams({
            grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            assertion: await createJWT(serviceAccount)
          })
        });
        const { access_token } = await tokenRes.json();
        await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${access_token}`
          },
          body: JSON.stringify({
            message: {
              token: orangTua.fcm_token,
              notification: {
                title: judul,
                body: pesan
              },
              data: {
                setoran_id: String(setoran_id)
              },
              android: {
                notification: {
                  sound: 'default'
                }
              }
            }
          })
        });
      } catch (fcmError) {
        console.log('FCM error (non-fatal):', fcmError.message);
      }
    }
    return new Response(JSON.stringify({
      success: true,
      pesan
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (e) {
    console.log('Error:', e.message);
    return new Response(JSON.stringify({
      error: e.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
async function createJWT(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  };
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  };
  const encode = (obj)=>btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signingInput = `${encode(header)}.${encode(payload)}`;
  const privateKey = serviceAccount.private_key.replace('-----BEGIN PRIVATE KEY-----', '').replace('-----END PRIVATE KEY-----', '').replace(/\n/g, '');
  const binaryKey = Uint8Array.from(atob(privateKey), (c)=>c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey('pkcs8', binaryKey, {
    name: 'RSASSA-PKCS1-v1_5',
    hash: 'SHA-256'
  }, false, [
    'sign'
  ]);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, new TextEncoder().encode(signingInput));
  const sig = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  return `${signingInput}.${sig}`;
}
