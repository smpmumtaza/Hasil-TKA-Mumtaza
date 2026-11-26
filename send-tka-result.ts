import nodemailer from "npm:nodemailer@10.6.1";

const allowedOrigin = "https://smpmumtaza.github.io";
const cors = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Vary": "Origin",
  "Cache-Control": "no-store",
};

function reply(status: number, message: string) {
  return Response.json({ message }, { status, headers: cors });
}

Deno.serve(async (request) => {
  if (request.headers.get("Origin") !== allowedOrigin) return reply(403, "Akses ditolak.");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return reply(405, "Metode tidak didukung.");

  const raw = await request.text();
  if (raw.length > 2048) return reply(400, "Permintaan tidak valid.");
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return reply(400, "Permintaan tidak valid.");
  }
  const identity = typeof input?.identity === "string" ? input.identity.trim() : "";
  const birth = typeof input?.birth === "string" ? input.birth : "";
  const code = typeof input?.code === "string" ? input.code.toLowerCase() : "";
  const email = typeof input?.email === "string" ? input.email.trim() : "";
  if (!identity || identity.length > 200 || !/^\d{4}-\d{2}-\d{2}$/.test(birth)
      || !/^[a-f0-9]{32}$/.test(code) || email.length > 254
      || !/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(email)) {
    return reply(400, "Periksa data dan alamat email.");
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const user = Deno.env.get("TKA_GMAIL_USER")?.trim();
  const password = Deno.env.get("TKA_GMAIL_APP_PASSWORD")?.replace(/\s/g, "");
  const from = Deno.env.get("TKA_FROM_EMAIL")?.trim();
  if (!url || !serviceRole || !user || !password || password.length !== 16 ||
      !from || !/^no-?reply@[a-z0-9-]+(?:\.[a-z0-9-]+)+$/i.test(from)) {
    return reply(503, "Layanan email noreply belum diaktifkan.");
  }

  try {
    const reservation = await fetch(url + "/rest/v1/rpc/reserve_tka_official_email", {
      method: "POST",
      headers: { apikey: serviceRole, Authorization: "Bearer " + serviceRole, "Content-Type": "application/json" },
      body: JSON.stringify({ p_identity: identity, p_birth: birth, p_code: code }),
      signal: AbortSignal.timeout(8000),
    });
    if (!reservation.ok) return reply(503, "Verifikasi email sementara tidak tersedia.");
    const [row] = await reservation.json();
    if (!row) return reply(429, "Periksa data Anda atau coba lagi setelah 10 menit.");
    const formatter = new Intl.NumberFormat("id-ID", { maximumFractionDigits: 2 });
    const body = [
      "Hasil TKA SMP Mumtaza",
      "",
      "Nama siswa: " + row.nama,
      "Bahasa Indonesia: " + formatter.format(row.bahasa_indonesia) + " (" + row.bahasa_indonesia_predikat + ")",
      "Matematika: " + formatter.format(row.matematika) + " (" + row.matematika_predikat + ")",
    ].join("\n");
    const smtp = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user, pass: password },
      connectionTimeout: 8000,
      greetingTimeout: 5000,
      socketTimeout: 10000,
    });
    const sent = await smtp.sendMail({
      from: { name: "Hasil TKA SMP Mumtaza", address: from },
      to: [{ address: email }],
      subject: "Hasil TKA SMP Mumtaza",
      text: body + "\n\nPesan otomatis. Mohon tidak membalas email ini.",
      headers: { "Auto-Submitted": "auto-generated" },
    });
    return sent.accepted.length === 1
      ? reply(200, "Email telah diterima layanan pengiriman.")
      : reply(502, "Email belum dapat dikirim. Coba lagi setelah 10 menit.");
  } catch {
    return reply(502, "Pengiriman belum dapat dikonfirmasi. Coba lagi setelah 10 menit.");
  }
});
