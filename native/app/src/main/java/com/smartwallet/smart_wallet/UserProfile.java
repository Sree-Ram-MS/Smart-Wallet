package com.smartwallet.smart_wallet;

/** The wallet owner + app preferences, as in the Flutter backup JSON. */
public class UserProfile {
    public String id;
    public String name;
    public String email;
    public String photoUrl = "";
    public String baseCurrency = "INR";
    public boolean biometricEnabled;
    public boolean isDarkMode = true;
    public boolean dailyReminderEnabled = true;
    public int dailyReminderHour = 20;
    public int dailyReminderMinute = 0;
    public boolean plannedReminderEnabled = true;
    public int plannedReminderDaysBefore = 2;

    public UserProfile() {}

    public boolean isGuest() {
        return "guest_user".equals(id) || "guest_001".equals(id)
                || (email != null && email.startsWith("guest@"));
    }
}
