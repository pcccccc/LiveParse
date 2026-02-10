globalThis.LiveParsePlugin = {
  apiVersion: 1,
  async fetch(payload) {
    const url = (payload && payload.url) || "https://httpbin.org/get";
    const resp = await Host.http.request({ url, method: "GET", timeout: 15 });
    return {
      ok: true,
      status: resp.status,
      url: resp.url,
      bodyTextPrefix: (resp.bodyText || "").slice(0, 200)
    };
  }
};
