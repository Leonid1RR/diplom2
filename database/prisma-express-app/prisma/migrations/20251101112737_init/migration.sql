/*
  Warnings:

  - The primary key for the `Product` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `expiration` on the `Product` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `Product` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `ProductBatch` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `expiration` on the `ProductBatch` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `ProductBatch` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `productCount` on the `ProductBatch` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `supplierId` on the `ProductBatch` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `ProductOnWarehouse` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `id` on the `ProductOnWarehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `productId` on the `ProductOnWarehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `warehouseId` on the `ProductOnWarehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `Store` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `id` on the `Store` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `Supplier` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `batchCount` on the `Supplier` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `Supplier` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `Supply` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `fromSupplierId` on the `Supply` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `Supply` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `toStoreId` on the `Supply` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `Warehouse` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `id` on the `Warehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `productCount` on the `Warehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `storeId` on the `Warehouse` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `reviews` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `fromStoreId` on the `reviews` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `reviews` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `toSupplierId` on the `reviews` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - The primary key for the `support_messages` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to alter the column `fromStoreId` on the `support_messages` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `fromSupplierId` on the `support_messages` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.
  - You are about to alter the column `id` on the `support_messages` table. The data in that column could be lost. The data in that column will be cast from `BigInt` to `Int`.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Product" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "price" REAL NOT NULL,
    "photo" TEXT
);
INSERT INTO "new_Product" ("description", "expiration", "id", "name", "photo", "price") SELECT "description", "expiration", "id", "name", "photo", "price" FROM "Product";
DROP TABLE "Product";
ALTER TABLE "new_Product" RENAME TO "Product";
CREATE TABLE "new_ProductBatch" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "price" REAL NOT NULL,
    "photo" TEXT,
    "productCount" INTEGER NOT NULL,
    "supplierId" INTEGER NOT NULL,
    CONSTRAINT "ProductBatch_supplierId_fkey" FOREIGN KEY ("supplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_ProductBatch" ("description", "expiration", "id", "name", "photo", "price", "productCount", "supplierId") SELECT "description", "expiration", "id", "name", "photo", "price", "productCount", "supplierId" FROM "ProductBatch";
DROP TABLE "ProductBatch";
ALTER TABLE "new_ProductBatch" RENAME TO "ProductBatch";
CREATE TABLE "new_ProductOnWarehouse" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "productId" INTEGER NOT NULL,
    "warehouseId" INTEGER NOT NULL,
    CONSTRAINT "ProductOnWarehouse_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "ProductOnWarehouse_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_ProductOnWarehouse" ("id", "productId", "warehouseId") SELECT "id", "productId", "warehouseId" FROM "ProductOnWarehouse";
DROP TABLE "ProductOnWarehouse";
ALTER TABLE "new_ProductOnWarehouse" RENAME TO "ProductOnWarehouse";
CREATE TABLE "new_Store" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "photo" TEXT,
    "password" TEXT NOT NULL
);
INSERT INTO "new_Store" ("address", "description", "id", "name", "password", "photo") SELECT "address", "description", "id", "name", "password", "photo" FROM "Store";
DROP TABLE "Store";
ALTER TABLE "new_Store" RENAME TO "Store";
CREATE TABLE "new_Supplier" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "batchCount" INTEGER,
    "password" TEXT NOT NULL,
    "photo" TEXT
);
INSERT INTO "new_Supplier" ("address", "batchCount", "description", "id", "name", "password", "photo") SELECT "address", "batchCount", "description", "id", "name", "password", "photo" FROM "Supplier";
DROP TABLE "Supplier";
ALTER TABLE "new_Supplier" RENAME TO "Supplier";
CREATE TABLE "new_Supply" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "fromSupplierId" INTEGER NOT NULL,
    "toStoreId" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    CONSTRAINT "Supply_fromSupplierId_fkey" FOREIGN KEY ("fromSupplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Supply_toStoreId_fkey" FOREIGN KEY ("toStoreId") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Supply" ("content", "fromSupplierId", "id", "status", "toStoreId") SELECT "content", "fromSupplierId", "id", "status", "toStoreId" FROM "Supply";
DROP TABLE "Supply";
ALTER TABLE "new_Supply" RENAME TO "Supply";
CREATE TABLE "new_Warehouse" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "productCount" INTEGER NOT NULL,
    "storeId" INTEGER NOT NULL,
    CONSTRAINT "Warehouse_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_Warehouse" ("id", "productCount", "storeId") SELECT "id", "productCount", "storeId" FROM "Warehouse";
DROP TABLE "Warehouse";
ALTER TABLE "new_Warehouse" RENAME TO "Warehouse";
CREATE UNIQUE INDEX "Warehouse_storeId_key" ON "Warehouse"("storeId");
CREATE TABLE "new_reviews" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "text" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "fromStoreId" INTEGER NOT NULL,
    "toSupplierId" INTEGER NOT NULL,
    CONSTRAINT "reviews_fromStoreId_fkey" FOREIGN KEY ("fromStoreId") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "reviews_toSupplierId_fkey" FOREIGN KEY ("toSupplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_reviews" ("createdAt", "fromStoreId", "id", "text", "toSupplierId") SELECT "createdAt", "fromStoreId", "id", "text", "toSupplierId" FROM "reviews";
DROP TABLE "reviews";
ALTER TABLE "new_reviews" RENAME TO "reviews";
CREATE TABLE "new_support_messages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "text" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "fromStoreId" INTEGER,
    "fromSupplierId" INTEGER,
    CONSTRAINT "support_messages_fromStoreId_fkey" FOREIGN KEY ("fromStoreId") REFERENCES "Store" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "support_messages_fromSupplierId_fkey" FOREIGN KEY ("fromSupplierId") REFERENCES "Supplier" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_support_messages" ("createdAt", "fromStoreId", "fromSupplierId", "id", "text") SELECT "createdAt", "fromStoreId", "fromSupplierId", "id", "text" FROM "support_messages";
DROP TABLE "support_messages";
ALTER TABLE "new_support_messages" RENAME TO "support_messages";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
