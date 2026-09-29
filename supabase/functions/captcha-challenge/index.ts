import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const challengeLifetimeMs = 5 * 60 * 1000;
const codeLength = 5;
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const colors = ['#2d4d9b', '#8b2f9f', '#23934b', '#d16a2f', '#6f3c9e'];

const glyphs: Record<string, string[]> = {
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  B: ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  C: ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  F: ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  G: ['01111', '10000', '10000', '10111', '10001', '10001', '01111'],
  H: ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  J: ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  K: ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  L: ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  M: ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  P: ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  Q: ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  R: ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  U: ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  W: ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
  X: ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  Z: ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  2: ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  3: ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  4: ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  5: ['11111', '10000', '10000', '11110', '00001', '00001', '11110'],
  6: ['01110', '10000', '10000', '11110', '10001', '10001', '01110'],
  7: ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  8: ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  9: ['01110', '10001', '10001', '01111', '00001', '00001', '01110'],
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type CaptchaRequest = {
  action?: unknown;
  challenge_id?: unknown;
  answer?: unknown;
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function requiredEnv(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value) return value;
  }
  throw new Error(`Missing environment variable: ${names.join(' or ')}`);
}

function randomInt(max: number) {
  const limit = 0x100000000 - (0x100000000 % max);
  const bytes = new Uint32Array(1);
  do {
    crypto.getRandomValues(bytes);
  } while (bytes[0] >= limit);
  return bytes[0] % max;
}

function randomFloat(min: number, max: number) {
  return min + randomInt(1_000_000) / 1_000_000 * (max - min);
}

function pick<T>(items: T[]) {
  return items[randomInt(items.length)];
}

function createCode() {
  return Array.from({ length: codeLength }, () =>
    alphabet[randomInt(alphabet.length)]
  ).join('');
}

function normalizeAnswer(value: unknown) {
  if (typeof value !== 'string') return null;
  const answer = value.trim().toUpperCase();
  return /^[A-Z0-9]{5}$/.test(answer) ? answer : null;
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

async function hashAnswer(secret: string, challengeId: string, answer: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${challengeId}:${answer}`),
  );
  return Array.from(new Uint8Array(signature), (byte) =>
    byte.toString(16).padStart(2, '0')
  ).join('');
}

function glyphPath(character: string, x: number, y: number, cell: number) {
  const rows = glyphs[character];
  if (!rows) throw new Error('Unsupported CAPTCHA character');

  let path = '';
  rows.forEach((row, rowIndex) => {
    [...row].forEach((pixel, columnIndex) => {
      if (pixel !== '1') return;
      const left = x + columnIndex * cell;
      const top = y + rowIndex * cell;
      path += `M${left} ${top}h${cell}v${cell}h-${cell}z`;
    });
  });
  return path;
}

function createSvg(code: string) {
  const width = 360;
  const height = 86;
  let svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}">`;
  svg += `<path d="M0 0h${width}v${height}H0z" fill="#f4f5f4"/>`;

  for (let index = 0; index < 18; index++) {
    const startX = randomFloat(-30, width - 20);
    const endX = randomFloat(20, width + 30);
    const startY = randomFloat(4, height - 4);
    const endY = randomFloat(4, height - 4);
    const controlX = randomFloat(60, width - 60);
    const controlY = randomFloat(-25, height + 25);
    svg += `<path d="M${startX.toFixed(1)} ${startY.toFixed(1)} Q${controlX.toFixed(1)} ${controlY.toFixed(1)} ${endX.toFixed(1)} ${endY.toFixed(1)}" fill="none" stroke="${pick(colors)}" stroke-width="${randomFloat(0.5, 1.8).toFixed(1)}" opacity="0.62"/>`;
  }

  const cell = 5;
  code.split('').forEach((character, index) => {
    const x = 19 + index * 67;
    const y = 22 + randomFloat(-4, 7);
    const centerX = x + 12.5;
    const centerY = y + 17.5;
    const rotation = randomFloat(-18, 18).toFixed(1);
    svg += `<path d="${glyphPath(character, x, y, cell)}" fill="${pick(colors)}" transform="rotate(${rotation} ${centerX} ${centerY})"/>`;
  });

  svg += '</svg>';
  return svg;
}

async function createChallenge(supabase: ReturnType<typeof createClient>, secret: string) {
  // ponytail: no IP-based issuance limit yet; add a durable rate-limit table if abuse requires it.
  await supabase
    .from('captcha_challenges')
    .delete()
    .lt('expires_at', new Date(Date.now() - challengeLifetimeMs).toISOString());

  const id = crypto.randomUUID();
  const code = createCode();
  const answerHash = await hashAnswer(secret, id, code);
  const expiresAt = new Date(Date.now() + challengeLifetimeMs).toISOString();

  const { error } = await supabase.from('captcha_challenges').insert({
    id,
    answer_hash: answerHash,
    expires_at: expiresAt,
  });
  if (error) throw error;

  return response({
    challenge_id: id,
    svg: createSvg(code),
  });
}

async function verifyChallenge(
  supabase: ReturnType<typeof createClient>,
  secret: string,
  body: CaptchaRequest,
) {
  const challengeId = body.challenge_id;
  const answer = normalizeAnswer(body.answer);
  if (!isUuid(challengeId) || answer == null) {
    return response({ valid: false });
  }

  const answerHash = await hashAnswer(secret, challengeId, answer);
  const { data, error } = await supabase.rpc('consume_captcha_challenge', {
    p_challenge_id: challengeId,
    p_answer_hash: answerHash,
  });
  if (error) throw error;

  return response({ valid: data === true });
}

serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed' }, 405);

  try {
    const body = await request.json() as CaptchaRequest;
    const action = body.action;
    const supabaseUrl = requiredEnv('SUPABASE_URL', 'SB_URL');
    const serviceRoleKey = requiredEnv(
      'SUPABASE_SERVICE_ROLE_KEY',
      'SB_SERVICE_KEY',
    );
    const secret = requiredEnv('CAPTCHA_HMAC_SECRET');
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    if (action === 'create') return await createChallenge(supabase, secret);
    if (action === 'verify') return await verifyChallenge(supabase, secret, body);
    return response({ error: 'Invalid action' }, 400);
  } catch (error) {
    console.error('CAPTCHA function error');
    return response({ error: 'CAPTCHA service unavailable' }, 500);
  }
});
