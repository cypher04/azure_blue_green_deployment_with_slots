require("dotenv").config();
const express = require("express");
const path = require("path");
const { getPool } = require("./db");
const itemRoutes = require("./routes/items");

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public")));

// View engine
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// Routes
app.use("/api/items", itemRoutes);

// Home page
app.get("/", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query("SELECT 1 AS connected");
    res.render("index", { dbStatus: "Connected", items: [] });
  } catch (err) {
    res.render("index", { dbStatus: "Disconnected", items: [] });
  }
});

// Health check endpoint
app.get("/health", async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request().query("SELECT 1");
    res.json({ status: "healthy", database: "connected" });
  } catch (err) {
    res.status(503).json({ status: "unhealthy", database: "disconnected", error: err.message });
  }
});

// Initialize database table and start server
async function start() {
  try {
    const pool = await getPool();
    await pool.request().query(`
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='items' AND xtype='U')
      CREATE TABLE items (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        description NVARCHAR(1000),
        created_at DATETIME DEFAULT GETDATE()
      )
    `);
    console.log("Database initialized successfully");
  } catch (err) {
    console.warn("Database init skipped (will retry on request):", err.message);
  }

  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

start();
