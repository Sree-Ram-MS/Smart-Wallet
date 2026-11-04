package com.smartwallet.smart_wallet;

/** A reusable transaction template, as in the Flutter backup JSON. */
public class Template {
    public String id;
    public String name;
    public String type; // "income" | "expense" | "transfer"
    public double amount;
    public String accountId;
    public String toAccountId; // nullable, optional
    public String categoryId; // nullable
    public String note = "";

    public Template() {}
}
