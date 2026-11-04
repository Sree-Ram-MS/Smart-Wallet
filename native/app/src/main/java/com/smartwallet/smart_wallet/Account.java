package com.smartwallet.smart_wallet;

/** One wallet / bank account / card. Field names match the Flutter
 *  .smartwallet backup JSON exactly (see reference/starter_wallet_data.json). */
public class Account {
    public String id;
    public String name;
    public double balance;
    public String currency = "INR";
    /** ARGB colour as an unsigned 32-bit value (Flutter Color.value), kept as long. */
    public long colorValue = 0xFF6C63FFL;
    public String emoji = "\uD83D\uDCB3"; // 💳
    public String notes = "";
    public boolean isEnabledForCalc = true;
    public String imagePath; // nullable, optional in the JSON
    public String cardType = ""; // e.g. "Mastercard"; optional in the JSON

    public Account() {}

    public Account(String id, String name, double balance) {
        this.id = id;
        this.name = name;
        this.balance = balance;
    }

    /** Colour as an Android ARGB int. */
    public int colorInt() {
        return (int) colorValue;
    }
}
