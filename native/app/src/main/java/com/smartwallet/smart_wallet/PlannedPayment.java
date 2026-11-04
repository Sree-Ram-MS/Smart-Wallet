package com.smartwallet.smart_wallet;

import java.util.ArrayList;
import java.util.List;

/** A scheduled / recurring payment, as in the Flutter backup JSON. */
public class PlannedPayment {
    public String id;
    public String name;
    public double amount;
    public String accountId;
    public String categoryId; // nullable
    public boolean isRecurring;
    public String period; // "daily" | "weekly" | "monthly" | "yearly", nullable
    public String nextDueDate; // ISO-8601
    public String note = "";
    public String endType = "never"; // "never" | "until_date" | "occurrences"
    public String untilDate; // nullable
    public Integer totalOccurrences; // nullable
    public int currentOccurrence = 1;
    public boolean isCompleted;
    public String lastPaidDate; // nullable
    public boolean isSplit;
    public List<SplitMember> splits = new ArrayList<>();

    public PlannedPayment() {}
}
