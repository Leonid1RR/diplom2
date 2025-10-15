-- CreateTable
CREATE TABLE "Supply" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "fromSupplierId" INTEGER NOT NULL,
    "toStoreId" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    CONSTRAINT "Supply_fromSupplierId_fkey" FOREIGN KEY ("fromSupplierId") REFERENCES "Supplier" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "Supply_toStoreId_fkey" FOREIGN KEY ("toStoreId") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
