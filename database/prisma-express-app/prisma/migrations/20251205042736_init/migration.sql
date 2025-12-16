/*
  Warnings:

  - You are about to drop the `ProductBatch` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
PRAGMA foreign_keys=off;
DROP TABLE "ProductBatch";
PRAGMA foreign_keys=on;

-- CreateTable
CREATE TABLE "batches" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "price" REAL NOT NULL,
    "photo" TEXT,
    "itemsPerBatch" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,
    "supplierId" INTEGER NOT NULL,
    CONSTRAINT "batches_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Supply" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "fromSupplierId" INTEGER NOT NULL,
    "toStoreId" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "deliveryTime" DATETIME,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Supply_fromSupplierId_fkey" FOREIGN KEY ("fromSupplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Supply_toStoreId_fkey" FOREIGN KEY ("toStoreId") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Supply" ("content", "deliveryTime", "fromSupplierId", "id", "status", "toStoreId") SELECT "content", "deliveryTime", "fromSupplierId", "id", "status", "toStoreId" FROM "Supply";
DROP TABLE "Supply";
ALTER TABLE "new_Supply" RENAME TO "Supply";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
