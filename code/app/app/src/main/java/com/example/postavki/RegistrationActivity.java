package com.example.postavki;

import android.content.Intent;
import android.os.Bundle;
import android.widget.*;
import androidx.appcompat.app.AppCompatActivity;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class RegistrationActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_registration);

        RadioGroup roleGroup = findViewById(R.id.roleGroup);
        EditText name = findViewById(R.id.editName);
        EditText password = findViewById(R.id.editPassword);
        EditText address = findViewById(R.id.editAddress);
        EditText description = findViewById(R.id.editDescription);
        Button registerBtn = findViewById(R.id.btnRegisterUser);

        registerBtn.setOnClickListener(v -> {
            int roleId = roleGroup.getCheckedRadioButtonId();
            String userName = name.getText().toString();
            String pass = password.getText().toString();
            String addr = address.getText().toString();
            String desc = description.getText().toString();

            if (roleId == R.id.radioStore) {
                ApiClient.getService(this).createStore(new Store(userName, pass, addr, desc, "store.png"))
                        .enqueue(new Callback<Store>() {
                            @Override
                            public void onResponse(Call<Store> call, Response<Store> response) {
                                if (response.isSuccessful()) {
                                    int storeId = response.body().getId();
                                    ApiClient.getService(RegistrationActivity.this).createWarehouse(new Warehouse(0, storeId))
                                            .enqueue(new Callback<Warehouse>() {
                                                @Override
                                                public void onResponse(Call<Warehouse> call, Response<Warehouse> resp) {
                                                    Toast.makeText(RegistrationActivity.this, "Магазин и склад зарегистрированы", Toast.LENGTH_SHORT).show();
                                                    startActivity(new Intent(RegistrationActivity.this, LoginActivity.class));
                                                    finish();
                                                }

                                                @Override
                                                public void onFailure(Call<Warehouse> call, Throwable t) {}
                                            });
                                }
                            }

                            @Override
                            public void onFailure(Call<Store> call, Throwable t) {}
                        });
            } else if (roleId == R.id.radioSupplier) {
                ApiClient.getService(this).createSupplier(new Supplier(userName, pass, addr, desc, 0))
                        .enqueue(new Callback<Supplier>() {
                            @Override
                            public void onResponse(Call<Supplier> call, Response<Supplier> response) {
                                Toast.makeText(RegistrationActivity.this, "Поставщик зарегистрирован", Toast.LENGTH_SHORT).show();
                                startActivity(new Intent(RegistrationActivity.this, LoginActivity.class));
                                finish();
                            }

                            @Override
                            public void onFailure(Call<Supplier> call, Throwable t) {}
                        });
            }
        });
    }
}
