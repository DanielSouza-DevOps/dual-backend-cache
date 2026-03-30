import express from "express";

const PATH_PREFIX = (process.env.PATH_PREFIX || "").replace(/\/$/, "");
const STATIC_TEXT = "Static text from Node.js";
const CACHE_TTL_SEC = Math.max(
  1,
  parseInt(process.env.CACHE_TTL_SEC ?? "10", 10) || 10,
);

/** @type {Map<string, { expiresAt: number; value: string }>} */
const _cache = new Map();

function getCached(key, producer) {
  const ttlMs = CACHE_TTL_SEC * 1000;
  const now = performance.now();
  const entry = _cache.get(key);
  if (entry != null && entry.expiresAt > now) {
    return { hit: true, value: entry.value };
  }
  const value = producer();
  _cache.set(key, { expiresAt: now + ttlMs, value });
  return { hit: false, value };
}

function stripApiGatewayStagePath(req, _res, next) {
  const stage = process.env.API_GATEWAY_STAGE_NAME?.trim();
  if (!stage) return next();
  const prefix = `/${stage}`;
  const u = req.url ?? "";
  if (u === prefix || u.startsWith(`${prefix}/`) || u.startsWith(`${prefix}?`)) {
    const rest = u.slice(prefix.length);
    req.url = rest.length === 0 ? "/" : rest.startsWith("/") || rest.startsWith("?") ? rest : `/${rest}`;
  }
  next();
}

function normalizeApiGatewayProxyPath(req, _res, next) {
  if (!PATH_PREFIX) return next();
  const raw = req.url ?? "/";
  const q = raw.indexOf("?");
  const pathname = q >= 0 ? raw.slice(0, q) : raw;
  const search = q >= 0 ? raw.slice(q) : "";
  const under =
    pathname === PATH_PREFIX || pathname === `${PATH_PREFIX}/` || pathname.startsWith(`${PATH_PREFIX}/`);
  if (!under && pathname.startsWith("/")) {
    req.url = `${PATH_PREFIX}${pathname === "/" ? "" : pathname}${search}`;
  }
  next();
}

export function createApp() {
  const app = express();
  app.use(stripApiGatewayStagePath);
  app.use(normalizeApiGatewayProxyPath);

  const router = express.Router();

  /** GET / on /node (API Gateway root resource without {proxy+}); static text with cache. */
  router.get("/", (_req, res) => {
    const { hit, value } = getCached("static", () => STATIC_TEXT);
    res.set("X-Cache", hit ? "HIT" : "MISS");
    res.set("Cache-Control", `private, max-age=${CACHE_TTL_SEC}`);
    res.type("text/plain; charset=utf-8").send(value);
  });

  router.get("/health", (_req, res) => {
    res.status(200).send("health");
  });

  if (PATH_PREFIX) {
    app.use(PATH_PREFIX, router);
  } else {
    app.use(router);
  }
  return app;
}
