enum EnvironmentType { dev, prod }

class Environment {
  static EnvironmentType _current = EnvironmentType.prod;

  static EnvironmentType get current => _current;

  static void setEnvironment(EnvironmentType env) {
    _current = env;
  }

  static bool get isDev => _current == EnvironmentType.dev;
  static bool get isProd => _current == EnvironmentType.prod;

  // Firebase configuration placeholders
  static String get firebaseProjectId {
    switch (_current) {
      case EnvironmentType.dev:
        return 'mcs-management'; // TODO: Replace with actual dev project ID
      case EnvironmentType.prod:
        return 'mcs-management'; // TODO: Replace with actual prod project ID
    }
  }

  // Shop configuration (single shop for now)
  static String get shopId {
    switch (_current) {
      case EnvironmentType.dev:
        return 'shop_dev_001'; // TODO: Replace with actual dev shop ID
      case EnvironmentType.prod:
        return 'shop_prod_001'; // TODO: Replace with actual prod shop ID
    }
  }

  static String get shopName {
    switch (_current) {
      case EnvironmentType.dev:
        return 'Master Computer And Stationeries';
      case EnvironmentType.prod:
        return 'Master Computer And Stationeries';
    }
  }

  static String get shopAddress {
    switch (_current) {
      case EnvironmentType.dev:
        return 'Binahali Boroitola Bazar, Adamdighi, Bogura';
      case EnvironmentType.prod:
        return 'Binahali Boroitola Bazar, Adamdighi, Bogura'; // TODO: Update with actual address
    }
  }

  static String get shopPhone {
    switch (_current) {
      case EnvironmentType.dev:
        return '+880177-332235, +8801323-172800';
      case EnvironmentType.prod:
        return '+880177-332235, +8801323-172800'; // TODO: Update with actual phone
    }
  }

  static String? get shopEmail {
    switch (_current) {
      case EnvironmentType.dev:
        return 'mcstopu@gmail.com.com';
      case EnvironmentType.prod:
        return 'mcstopu@gmail.com.com'; // TODO: Update with actual email
    }
  }
}
