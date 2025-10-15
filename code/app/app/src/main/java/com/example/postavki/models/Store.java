package com.example.postavki;

public class Store {
    private int id;
    private String name;
    private String password;
    private String address;
    private String description;
    private String photo;

    public Store(String name, String password, String address, String description, String photo) {
        this.name = name;
        this.password = password;
        this.address = address;
        this.description = description;
        this.photo = photo;
    }

    public int getId() {
        return id;
    }
}
