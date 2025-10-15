const express = require("express");
const prisma = require("../prisma");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const warehouses = await prisma.warehouse.findMany({ include: { products: true, store: true } });
    res.json(warehouses);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/:id", async (req, res) => {
  try {
    const warehouse = await prisma.warehouse.findUnique({
      where: { id: Number(req.params.id) },
      include: { products: true, store: true },
    });
    if (!warehouse) return res.status(404).json({ error: "Not found" });
    res.json(warehouse);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/", async (req, res) => {
  try {
    const warehouse = await prisma.warehouse.create({ data: req.body });
    res.status(201).json(warehouse);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const warehouse = await prisma.warehouse.update({
      where: { id: Number(req.params.id) },
      data: req.body,
    });
    res.json(warehouse);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    await prisma.warehouse.delete({ where: { id: Number(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
