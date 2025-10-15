/*
  Warnings:

  - You are about to drop the column `warehouseId` on the `Product` table. All the data in the column will be lost.
  - Added the required column `password` to the `Store` table without a default value. This is not possible if the table is not empty.
  - Added the required column `name` to the `Supplier` table without a default value. This is not possible if the table is not empty.
  - Added the required column `password` to the `Supplier` table without a default value. This is not possible if the table is not empty.

*/
-- CreateTable
CREATE TABLE "ProductOnWarehouse" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "productId" INTEGER NOT NULL,
    "warehouseId" INTEGER NOT NULL,
    CONSTRAINT "ProductOnWarehouse_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "ProductOnWarehouse_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Product" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "price" REAL NOT NULL,
    "photo" TEXT NOT NULL
);
INSERT INTO "new_Product" ("description", "expiration", "id", "name", "photo", "price") SELECT "description", "expiration", "id", "name", "photo", "price" FROM "Product";
DROP TABLE "Product";
ALTER TABLE "new_Product" RENAME TO "Product";
CREATE TABLE "new_Store" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "photo" TEXT NOT NULL,
    "password" TEXT NOT NULL
);
INSERT INTO "new_Store" ("address", "description", "id", "name", "photo") SELECT "address", "description", "id", "name", "photo" FROM "Store";
DROP TABLE "Store";
ALTER TABLE "new_Store" RENAME TO "Store";
CREATE TABLE "new_Supplier" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "batchCount" INTEGER NOT NULL,
    "password" TEXT NOT NULL
);
INSERT INTO "new_Supplier" ("address", "batchCount", "description", "id") SELECT "address", "batchCount", "description", "id" FROM "Supplier";
DROP TABLE "Supplier";
ALTER TABLE "new_Supplier" RENAME TO "Supplier";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
