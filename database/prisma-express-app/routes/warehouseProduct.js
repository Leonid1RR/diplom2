const express = require("express");
const prisma = require("../prisma");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const wps = await prisma.warehouseProduct.findMany({ include: { product: true, warehouse: true } });
    res.json(wps);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/:id", async (req, res) => {
  try {
    const wp = await prisma.warehouseProduct.findUnique({
      where: { id: Number(req.params.id) },
      include: { product: true, warehouse: true },
    });
    if (!wp) return res.status(404).json({ error: "Not found" });
    res.json(wp);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/", async (req, res) => {
  try {
    const wp = await prisma.warehouseProduct.create({ data: req.body });
    res.status(201).json(wp);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const wp = await prisma.warehouseProduct.update({
      where: { id: Number(req.params.id) },
      data: req.body,
    });
    res.json(wp);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    await prisma.warehouseProduct.delete({ where: { id: Number(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
