enum WalletType {
  bkashAgent, // Bkash Agent
  nagadAgent, // Nagad Agent
  rocketAgent, // Rocket Agent
  gp1, // GP1
  gp2, // GP2
  blRetailer, // BL Retailer
  bkashMerchant, // Bkash Merchant
  nagadB2B, // Nagad B2B
  bkashB2B, // Bkash B2B
  profitDeduction, // Profit deduction tracking (no balance impact)
  custom, // Custom wallet for personal MSF balances
}

extension WalletTypeExtension on WalletType {
  String get label {
    switch (this) {
      case WalletType.bkashAgent:
        return 'Bkash Agent';
      case WalletType.nagadAgent:
        return 'Nagad Agent';
      case WalletType.rocketAgent:
        return 'Rocket Agent';
      case WalletType.gp1:
        return 'GP1';
      case WalletType.gp2:
        return 'GP2';
      case WalletType.blRetailer:
        return 'BL Retailer';
      case WalletType.bkashMerchant:
        return 'Bkash Merchant';
      case WalletType.nagadB2B:
        return 'Nagad B2B';
      case WalletType.bkashB2B:
        return 'Bkash B2B';
      case WalletType.profitDeduction:
        return 'Profit Deduction Tracking';
      case WalletType.custom:
        return 'Custom Wallet';
    }
  }

  String get name {
    return label;
  }
}
