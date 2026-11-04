package com.smartwallet.smart_wallet;

/** Money lent to / borrowed from a person, as in the Flutter backup JSON. */
public class DebtCredit {
    public String id;
    public String direction; // "lent" | "borrowed"
    public String personName;
    public double amount;
    public String accountId;
    public String categoryId; // nullable, optional
    public String startDate; // ISO-8601
    public String dueDate; // ISO-8601, nullable
    public String status = "active"; // "active" | "closed"
    public String notes = "";
    /** false = opening-balance / historical record only, no account movement. */
    public boolean affectsAccount = true;
    public String transactionId; // nullable, optional
    public String settlementTransactionId; // nullable, optional

    public DebtCredit() {}
}
