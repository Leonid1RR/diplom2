package com.example.postavki;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

public class ServerIpActivity extends AppCompatActivity {

    private EditText editServerIp;
    private Button btnSaveIp;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_server_ip);

        editServerIp = findViewById(R.id.editServerIp);
        btnSaveIp = findViewById(R.id.btnSaveIp);

        // Загружаем сохраненный IP, если есть
        SharedPreferences prefs = getSharedPreferences("app_prefs", MODE_PRIVATE);
        String savedIp = prefs.getString("server_ip", "");
        editServerIp.setText(savedIp);

        btnSaveIp.setOnClickListener(v -> {
            String ip = editServerIp.getText().toString().trim();
            if (ip.isEmpty()) {
                Toast.makeText(this, "Введите IP сервера", Toast.LENGTH_SHORT).show();
                return;
            }

            // Сохраняем IP
            prefs.edit().putString("server_ip", ip).apply();

            // Переходим к экрану входа
            startActivity(new Intent(ServerIpActivity.this, LoginActivity.class));
            finish();
        });
    }
}
