package com.smartwallet.smart_wallet;

/** One person's share of a split transaction / planned payment. */
public class SplitMember {
    public String id;
    public String name;
    public double amount;
    public boolean isPaid;
    public String paidDate; // ISO-8601 string, nullable
    public String paidAccountId; // nullable, optional

    public SplitMember() {}

    public SplitMember(String id, String name, double amount, boolean isPaid) {
        this.id = id;
        this.name = name;
        this.amount = amount;
        this.isPaid = isPaid;
    }
}
