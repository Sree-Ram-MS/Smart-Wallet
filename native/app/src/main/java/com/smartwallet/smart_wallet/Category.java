package com.smartwallet.smart_wallet;

/** Income/expense category; parentId != null makes it a sub-category. */
public class Category {
    public String id;
    public String name;
    public String type; // "income" | "expense"
    public long colorValue = 0xFF6C63FFL;
    public String icon = "\uD83D\uDCE6"; // 📦 (emoji)
    public String imagePath; // nullable, optional
    public String parentId; // nullable = top-level

    public Category() {}

    public Category(String id, String name, String type) {
        this.id = id;
        this.name = name;
        this.type = type;
    }

    public int colorInt() {
        return (int) colorValue;
    }
}
