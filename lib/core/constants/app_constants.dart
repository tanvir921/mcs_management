/// Application-wide constants
class AppConstants {
  // App metadata
  static const String appName = "MCS Management";
  static const String currency = "BDT";
  static const int decimalPrecision = 2;

  // CRITICAL BUSINESS RULES:
  // - Never delete financial records
  // - Always use adjustment instead of delete
  // - Profit never modifies wallet balance
}
