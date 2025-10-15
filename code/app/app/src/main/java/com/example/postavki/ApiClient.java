package com.example.postavki;

import android.content.Context;
import android.content.SharedPreferences;

import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

public class ApiClient {

    private static Retrofit retrofit = null;

    public static Retrofit getRetrofit(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE);
        String ip = prefs.getString("server_ip", "192.168.1.100"); // дефолтный IP

        String BASE_URL = "http://" + ip + ":3000/"; // порт вашего сервера
        retrofit = new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .addConverterFactory(GsonConverterFactory.create())
                .build();
        return retrofit;
    }

    public static ApiService getService(Context context) {
        return getRetrofit(context).create(ApiService.class);
    }
}
