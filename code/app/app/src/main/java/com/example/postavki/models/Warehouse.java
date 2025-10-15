package com.example.postavki;

public class Warehouse {
    private int id;
    private int storeId;
    private int productCount;

    public Warehouse(int productCount, int storeId) {
        this.productCount = productCount;
        this.storeId = storeId;
    }

    public int getId() {
        return id;
    }
}
