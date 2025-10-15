package com.example.postavki;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class LoginActivity extends AppCompatActivity {

    private EditText editName, editPassword;
    private Button btnLoginStore, btnLoginSupplier, btnGoRegister;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        editName = findViewById(R.id.editName);
        editPassword = findViewById(R.id.editPassword);
        btnLoginStore = findViewById(R.id.btnLoginStore);
        btnLoginSupplier = findViewById(R.id.btnLoginSupplier);
        btnGoRegister = findViewById(R.id.btnGoRegister);

        btnGoRegister.setOnClickListener(v ->
                startActivity(new Intent(LoginActivity.this, RegistrationActivity.class))
        );

        btnLoginStore.setOnClickListener(v -> {
            String name = editName.getText().toString();
            String password = editPassword.getText().toString();

            ApiClient.getService(this).loginStore(new LoginRequest(name, password))
                    .enqueue(new Callback<LoginResponse>() {
                        @Override
                        public void onResponse(Call<LoginResponse> call, Response<LoginResponse> response) {
                            if (response.isSuccessful()) {
                                startActivity(new Intent(LoginActivity.this, HomeActivity.class));
                                finish();
                            } else {
                                Toast.makeText(LoginActivity.this, "Ошибка входа", Toast.LENGTH_SHORT).show();
                            }
                        }

                        @Override
                        public void onFailure(Call<LoginResponse> call, Throwable t) {
                            Toast.makeText(LoginActivity.this, "Ошибка сети", Toast.LENGTH_SHORT).show();
                        }
                    });
        });

        btnLoginSupplier.setOnClickListener(v -> {
            String name = editName.getText().toString();
            String password = editPassword.getText().toString();

            ApiClient.getService(this).loginSupplier(new LoginRequest(name, password))
                    .enqueue(new Callback<LoginResponse>() {
                        @Override
                        public void onResponse(Call<LoginResponse> call, Response<LoginResponse> response) {
                            if (response.isSuccessful()) {
                                startActivity(new Intent(LoginActivity.this, HomeActivity.class));
                                finish();
                            } else {
                                Toast.makeText(LoginActivity.this, "Ошибка входа", Toast.LENGTH_SHORT).show();
                            }
                        }

                        @Override
                        public void onFailure(Call<LoginResponse> call, Throwable t) {
                            Toast.makeText(LoginActivity.this, "Ошибка сети", Toast.LENGTH_SHORT).show();
                        }
                    });
        });
    }
}
