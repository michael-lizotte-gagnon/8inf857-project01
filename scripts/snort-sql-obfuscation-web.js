const { execFile } = require("node:child_process");
const http = require("node:http");

const mysqlHost = process.env.MYSQL_HOST || "snort-target";
const mysqlUser = process.env.MYSQL_USER || "snort_test";
const mysqlPassword = process.env.MYSQL_PASSWORD;

if (!mysqlPassword) {
  throw new Error("MYSQL_PASSWORD is required");
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, "http://localhost");
  if (request.method === "GET" && url.pathname === "/health") {
    response.writeHead(200).end("OK\n");
    return;
  }

  const query = url.searchParams.get("query");
  if (
    request.method !== "GET" ||
    url.pathname !== "/execute" ||
    query === null
  ) {
    response.writeHead(404).end("Not found\n");
    return;
  }

  execFile(
    "mariadb",
    [
      "--batch",
      "--skip-column-names",
      "--protocol=TCP",
      "--skip-ssl",
      `--host=${mysqlHost}`,
      `--user=${mysqlUser}`,
      "--execute",
      query,
    ],
    {
      env: { ...process.env, MYSQL_PWD: mysqlPassword },
      timeout: 10000,
      maxBuffer: 1024 * 1024,
    },
    (error, stdout, stderr) => {
      if (error) {
        console.error(`MariaDB query failed: ${stderr || error.message}`);
        response.writeHead(502).end("MariaDB query failed\n");
        return;
      }

      response.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
      response.end(stdout);
    },
  );
});

server.listen(80, "0.0.0.0", () => {
  console.log("SQL obfuscation test server listening on port 80.");
});
