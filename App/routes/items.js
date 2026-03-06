const express = require("express");
const router = express.Router();
const { getPool, sql } = require("../db");

// GET all items
router.get("/", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query("SELECT * FROM items ORDER BY created_at DESC");
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET single item
router.get("/:id", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool
      .request()
      .input("id", sql.Int, req.params.id)
      .query("SELECT * FROM items WHERE id = @id");
    if (!result.recordset.length) return res.status(404).json({ error: "Item not found" });
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST create item
router.post("/", async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) return res.status(400).json({ error: "Name is required" });
    const pool = await getPool();
    const result = await pool
      .request()
      .input("name", sql.NVarChar(255), name)
      .input("description", sql.NVarChar(1000), description || null)
      .query("INSERT INTO items (name, description) OUTPUT INSERTED.* VALUES (@name, @description)");
    res.status(201).json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT update item
router.put("/:id", async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) return res.status(400).json({ error: "Name is required" });
    const pool = await getPool();
    const result = await pool
      .request()
      .input("id", sql.Int, req.params.id)
      .input("name", sql.NVarChar(255), name)
      .input("description", sql.NVarChar(1000), description || null)
      .query("UPDATE items SET name = @name, description = @description WHERE id = @id; SELECT * FROM items WHERE id = @id");
    if (!result.recordset.length) return res.status(404).json({ error: "Item not found" });
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE item
router.delete("/:id", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool
      .request()
      .input("id", sql.Int, req.params.id)
      .query("DELETE FROM items WHERE id = @id");
    if (!result.rowsAffected[0]) return res.status(404).json({ error: "Item not found" });
    res.json({ message: "Item deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
