import { createApp } from "./app.js";

const PORT = process.env.PORT || 3000;
const app = createApp();

app.listen(PORT, () => {
  const base = (process.env.PATH_PREFIX || "").replace(/\/$/, "") || "(root)";
  console.log(`Node API on port ${PORT}, base ${base}`);
});
