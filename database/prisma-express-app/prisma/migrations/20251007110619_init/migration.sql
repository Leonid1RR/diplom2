-- AlterTable
ALTER TABLE "Supplier" ADD COLUMN "photo" TEXT;

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
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
