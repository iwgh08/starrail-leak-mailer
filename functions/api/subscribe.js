// 웹앱의 '새 유출 알림 켜기'가 보낸 푸시 구독 정보를 KV(PUSH)에 저장한다.
// 사이트 전체가 Cloudflare Access로 잠겨 있어 로그인한 사람만 이 주소를 부를 수 있다.
// PC의 hsr_news.py(send_push)가 Cloudflare API로 이 KV를 읽어 알림을 보낸다.
export async function onRequestPost({ request, env }) {
  let sub;
  try {
    sub = await request.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }
  if (typeof sub?.endpoint !== "string" || !sub.endpoint.startsWith("https://") || !sub.keys?.p256dh || !sub.keys?.auth) {
    return new Response("bad request", { status: 400 });
  }
  // 같은 기기가 다시 등록하면 덮어쓰도록 endpoint로 키를 만든다
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(sub.endpoint));
  const id = [...new Uint8Array(hash)].slice(0, 8).map((b) => b.toString(16).padStart(2, "0")).join("");
  await env.PUSH.put(`sub:${id}`, JSON.stringify({ endpoint: sub.endpoint, keys: sub.keys }));
  return Response.json({ ok: true });
}
