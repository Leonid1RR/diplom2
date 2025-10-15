package com.example.postavki;

public class Supplier {
    private int id;
    private String name;
    private String password;
    private String address;
    private String description;
    private int batchCount;

    public Supplier(String name, String password, String address, String description, int batchCount) {
        this.name = name;
        this.password = password;
        this.address = address;
        this.description = description;
        this.batchCount = batchCount;
    }

    public int getId() {
        return id;
    }
}
