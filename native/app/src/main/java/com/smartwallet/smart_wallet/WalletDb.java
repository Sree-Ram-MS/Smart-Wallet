package com.smartwallet.smart_wallet;

import java.util.ArrayList;
import java.util.List;

/**
 * The whole wallet database in memory: the "data" object of a
 * smartwallet_backup v1 file. Pure Java (no Android imports) so the
 * shape can be used from JVM tests as well as from Store.
 */
public class WalletDb {
    public UserProfile user;
    public List<Account> accounts = new ArrayList<>();
    public List<Category> categories = new ArrayList<>();
    public List<Transaction> transactions = new ArrayList<>();
    public List<PlannedPayment> plannedPayments = new ArrayList<>();
    public List<DebtCredit> debtCredits = new ArrayList<>();
    public List<Template> templates = new ArrayList<>();
    public List<String> analyticsCardOrder = new ArrayList<>();
    /** ISO-8601 timestamp of the backup/file this DB came from. */
    public String createdAt = "";
}
