class AppConstants {
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String shopIdKey = 'shop_id';
  
  // Shop Types
  static const String shopTypeClothing = 'clothing';
  static const String shopTypeGrocery = 'grocery';
  static const String shopTypeGeneral = 'general';
  
  // Product Sizes (for clothing)
  static const List<String> clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  
  // Shoe Sizes (for footwear)
  static List<String> get shoeSizes => List.generate(35, (index) => (20 + index).toString());
  
  // All sizes (clothing + shoes)
  static List<String> get allSizes => [...clothingSizes, ...shoeSizes];
  
  // Currency (Таджикский сомони)
  static const String currencySymbol = 'сом.'; // Символ валюты - таджикский сомони
  static const String currencyName = 'сомони';
  // Для отображения иконки можно использовать эмодзи 💰 или другой символ
}
