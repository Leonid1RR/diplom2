const express = require("express");
const prisma = require("../prisma");
const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const batches = await prisma.productBatch.findMany({ include: { supplier: true, product: true } });
    res.json(batches);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get("/:id", async (req, res) => {
  try {
    const batch = await prisma.productBatch.findUnique({
      where: { id: Number(req.params.id) },
      include: { supplier: true, product: true },
    });
    if (!batch) return res.status(404).json({ error: "Not found" });
    res.json(batch);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/", async (req, res) => {
  try {
    const batch = await prisma.productBatch.create({ data: req.body });
    res.status(201).json(batch);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const batch = await prisma.productBatch.update({
      where: { id: Number(req.params.id) },
      data: req.body,
    });
    res.json(batch);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    await prisma.productBatch.delete({ where: { id: Number(req.params.id) } });
    res.json({ message: "Deleted" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
  