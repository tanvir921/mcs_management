enum EnvironmentType { dev, prod }

class Environment {
  static EnvironmentType _current = EnvironmentType.dev;

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
        return 'MCS Shop (Dev)';
      case EnvironmentType.prod:
        return 'MCS Shop';
    }
  }
}
