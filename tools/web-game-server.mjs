import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../web_build");
const port = Number(process.env.WEB_PORT || 5175);
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".webp": "image/webp",
  ".pck": "application/octet-stream",
  ".wasm": "application/wasm",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf"
};

const server = http.createServer((req, res) => {
  const raw = decodeURIComponent((req.url || "/").split("?")[0]);
  const rel = raw.replace(/^\/+/g, "");
  const file = path.resolve(root, rel || "index.html");
  const rootWithSep = root.endsWith(path.sep) ? root : root + path.sep;
  if (file !== root && !file.startsWith(rootWithSep)) {
    res.writeHead(403);
    res.end("forbidden");
    return;
  }
  fs.readFile(file, (err, data) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("not found");
      return;
    }
    const ext = path.extname(file).toLowerCase();
    const headers = {
      "Content-Type": mime[ext] || "application/octet-stream",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp"
    };
    if (ext === ".html" || ext === ".js" || ext === ".json") headers["Cache-Control"] = "no-cache";
    res.writeHead(200, headers);
    res.end(data);
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log("Godot Web Game Server running at http://127.0.0.1:" + port + "/");
});
