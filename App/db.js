const sql = require("mssql");

let pool = null;

/**
 * Parse the DATABASE_URL connection string from Azure App Settings
 * Format: Server=<server>;Database=<db>;User Id=<user>;Password=<pass>;
 */
function parseConnectionString(connStr) {
  const parts = {};
  connStr.split(";").forEach((part) => {
    const [key, ...rest] = part.split("=");
    if (key && rest.length) {
      parts[key.trim().toLowerCase()] = rest.join("=").trim();
    }
  });
  return parts;
}

function getConfig() {
  const connStr = process.env.DATABASE_URL;

  if (connStr && connStr.includes(";")) {
    const parsed = parseConnectionString(connStr);
    return {
      server: parsed["server"] || "localhost",
      database: parsed["database"] || "maindb",
      user: parsed["user id"] || "sa",
      password: parsed["password"] || "",
      options: {
        encrypt: true,
        trustServerCertificate: false,
      },
      pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000,
      },
    };
  }

  // Fallback to individual env vars (for local development)
  return {
    server: process.env.DB_SERVER || "localhost",
    database: process.env.DB_NAME || "maindb",
    user: process.env.DB_USER || "sa",
    password: process.env.DB_PASSWORD || "",
    options: {
      encrypt: true,
      trustServerCertificate: process.env.NODE_ENV !== "production",
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000,
    },
  };
}

async function getPool() {
  if (pool) return pool;
  const config = getConfig();
  pool = await sql.connect(config);
  return pool;
}

module.exports = { getPool, sql };
