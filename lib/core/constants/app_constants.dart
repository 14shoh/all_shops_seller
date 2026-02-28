class AppConstants {
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String shopIdKey = 'shop_id';
  
  // Shop Types
  static const String shopTypeClothing = 'clothing';
  static const String shopTypeGrocery = 'grocery';
  static const String shopTypeGeneral = 'general';
  
  // Product Sizes (for clothing) - расширенные буквенные размеры
  static const List<String> clothingSizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', '5XL'
  ];
  
  // Numeric sizes (for clothing) - цифровые размеры
  static List<String> get numericSizes => List.generate(31, (index) => (38 + index * 2).toString());
  
  // Shoe Sizes (for footwear) - размеры обуви
  static List<String> get shoeSizes => List.generate(35, (index) => (20 + index).toString());
  
  // All sizes (clothing + numeric + shoes)
  static List<String> get allSizes => [...clothingSizes, ...numericSizes, ...shoeSizes];
  
  // Product units (для grocery/general - выбор при добавлении)
  static const String unitPieces = 'шт';
  static const String unitKg = 'кг';
  static const String unitLiters = 'л';
  static const List<Map<String, String>> productUnits = [
    {'value': 'pieces', 'label': 'шт', 'short': 'шт'},
    {'value': 'kg', 'label': 'кг', 'short': 'кг'},
    {'value': 'liters', 'label': 'л', 'short': 'л'},
  ];
  // weight-маркеры для бэкенда (не меняем бэк): 0.001=шт, 1=кг, 2=л
  static const double weightMarkerPieces = 0.001;
  static const double weightMarkerKg = 1.0;
  static const double weightMarkerLiters = 2.0;
  
  // Currency (Таджикский сомони)
  static const String currencySymbol = 'сом.'; // Символ валюты - таджикский сомони
  static const String currencyName = 'сомони';
  // Для отображения иконки можно использовать эмодзи 💰 или другой символ
}
