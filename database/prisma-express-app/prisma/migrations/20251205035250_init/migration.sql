/*
  Warnings:

  - You are about to drop the column `batchCount` on the `Supplier` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Supply" ADD COLUMN "deliveryTime" DATETIME;

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_ProductOnWarehouse" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "productId" INTEGER NOT NULL,
    "warehouseId" INTEGER NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ProductOnWarehouse_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "ProductOnWarehouse_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_ProductOnWarehouse" ("id", "productId", "warehouseId") SELECT "id", "productId", "warehouseId" FROM "ProductOnWarehouse";
DROP TABLE "ProductOnWarehouse";
ALTER TABLE "new_ProductOnWarehouse" RENAME TO "ProductOnWarehouse";
CREATE TABLE "new_Supplier" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "photo" TEXT
);
INSERT INTO "new_Supplier" ("address", "description", "id", "name", "password", "photo") SELECT "address", "description", "id", "name", "password", "photo" FROM "Supplier";
DROP TABLE "Supplier";
ALTER TABLE "new_Supplier" RENAME TO "Supplier";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
