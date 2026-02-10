globalThis.LiveParsePlugin = {
  apiVersion: 1,
  ping(payload) {
    return { ok: true, echo: payload };
  },
  async pingAsync(payload) {
    return { ok: true, echo: payload, async: true };
  }
};
