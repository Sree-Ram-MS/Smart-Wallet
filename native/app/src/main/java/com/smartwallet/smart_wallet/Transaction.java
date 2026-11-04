package com.smartwallet.smart_wallet;

import java.util.ArrayList;
import java.util.List;

/** A single money movement. Dates stay as ISO-8601 strings, exactly as in
 *  the Flutter backup JSON ("2026-09-01T09:30:00.000"), so files round-trip. */
public class Transaction {
    public String id;
    public String type; // "income" | "expense" | "transfer"
    public double amount;
    public String accountId;
    public String toAccountId; // nullable, transfers only
    public String categoryId; // nullable
    public String date; // ISO-8601
    public String note = "";
    public boolean isSplit;
    public List<SplitMember> splits = new ArrayList<>();

    public Transaction() {}

    public Transaction(String id, String type, double amount, String accountId, String date) {
        this.id = id;
        this.type = type;
        this.amount = amount;
        this.accountId = accountId;
        this.date = date;
    }
}
