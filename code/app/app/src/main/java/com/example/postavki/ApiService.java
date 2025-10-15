package com.example.postavki;

import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.POST;

public interface ApiService {

    @POST("stores")
    Call<Store> createStore(@Body Store store);

    @POST("suppliers")
    Call<Supplier> createSupplier(@Body Supplier supplier);

    @POST("loginStore")
    Call<LoginResponse> loginStore(@Body LoginRequest loginRequest);

    @POST("loginSupplier")
    Call<LoginResponse> loginSupplier(@Body LoginRequest loginRequest);

    @POST("warehouses")
    Call<Warehouse> createWarehouse(@Body Warehouse warehouse);
}
