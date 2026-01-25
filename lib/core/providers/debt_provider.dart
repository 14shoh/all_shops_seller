import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../../config/app_config.dart';

class CustomerDebtModel {
  final int? id;
  final String customerName;
  final String? phone;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final String? description;
  final DateTime debtDate;
  final int shopId;
  final int userId;

  CustomerDebtModel({
    this.id,
    required this.customerName,
    this.phone,
    required this.amount,
    this.paidAmount = 0.0,
    this.remainingAmount = 0.0,
    this.description,
    required this.debtDate,
    required this.shopId,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'customerName': customerName,
      'amount': amount,
      'debtDate': debtDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      'shopId': shopId,
    };
    if (phone != null && phone!.trim().isNotEmpty) {
      json['phone'] = phone!.trim();
    }
    // Добавляем description только если он не пустой
    if (description != null && description!.isNotEmpty) {
      json['description'] = description!;
    }
    return json;
  }

  factory CustomerDebtModel.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] is num) ? json['amount'].toDouble() : double.parse(json['amount'].toString());
    final paidAmount = json['paidAmount'] != null
        ? ((json['paidAmount'] is num) ? json['paidAmount'].toDouble() : double.parse(json['paidAmount'].toString()))
        : 0.0;
    final remainingAmount = json['remainingAmount'] != null
        ? ((json['remainingAmount'] is num) ? json['remainingAmount'].toDouble() : double.parse(json['remainingAmount'].toString()))
        : (amount - paidAmount);
    
    return CustomerDebtModel(
      id: json['id'],
      customerName: json['customerName'],
      phone: json['phone'] as String?,
      amount: amount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      description: json['description'],
      debtDate: DateTime.parse(json['debtDate']),
      shopId: json['shopId'],
      userId: json['userId'],
    );
  }
}

class SupplierDebtModel {
  final int? id;
  final String supplierName;
  final double totalDebt;
  final double paidAmount;
  final double remainingAmount;
  final int shopId;
  final int userId;

  SupplierDebtModel({
    this.id,
    required this.supplierName,
    required this.totalDebt,
    this.paidAmount = 0.0,
    this.remainingAmount = 0.0,
    required this.shopId,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'supplierName': supplierName,
      'totalDebt': totalDebt,
      'paidAmount': paidAmount,
      'shopId': shopId,
    };
  }

  factory SupplierDebtModel.fromJson(Map<String, dynamic> json) {
    return SupplierDebtModel(
      id: json['id'],
      supplierName: json['supplierName'],
      totalDebt: (json['totalDebt'] is num) ? json['totalDebt'].toDouble() : double.parse(json['totalDebt'].toString()),
      paidAmount: (json['paidAmount'] is num) ? json['paidAmount'].toDouble() : double.parse(json['paidAmount'].toString()),
      remainingAmount: (json['remainingAmount'] is num) ? json['remainingAmount'].toDouble() : double.parse(json['remainingAmount'].toString()),
      shopId: json['shopId'],
      userId: json['userId'],
    );
  }
}

class DebtProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ConnectivityService _connectivityService = ConnectivityService();

  static const String _pendingDebtPaymentsKey = 'pending_debt_payments_v1';
  static const String _pendingCustomerDebtsKey = 'pending_customer_debts_v1';
  static const String _pendingSupplierDebtsKey = 'pending_supplier_debts_v1';

  static const String _cachedCustomerDebtsKey = 'cached_customer_debts_v1';
  static const String _cachedSupplierDebtsKey = 'cached_supplier_debts_v1';

  // tempId (локальный) -> realId (сервер) чтобы офлайн-платежи не терялись
  static const String _customerDebtIdMappingKey = 'customer_debt_id_mapping_v1';
  static const String _supplierDebtIdMappingKey = 'supplier_debt_id_mapping_v1';
  bool _isSyncingPendingDebtPayments = false;
  int _pendingDebtPaymentsCount = 0;
  StreamSubscription<bool>? _connectivitySubscription;

  String? _lastOperationMessage;

  DebtProvider() {
    _initializeConnectivityListener();
    _refreshPendingDebtPaymentsCount();
    // При старте (если интернет уже есть) — пытаемся сразу досинхронизировать очередь
    _connectivityService.hasConnection().then((hasConnection) async {
      if (hasConnection) {
        await syncPendingDebts();
        await syncPendingDebtPayments();
      }
    });
  }

  String _normalizeCustomerName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // Customer Debts
  List<CustomerDebtModel> _customerDebts = [];
  bool _isLoadingCustomerDebts = false;
  String? _customerDebtsError;

  // Supplier Debts
  List<SupplierDebtModel> _supplierDebts = [];
  bool _isLoadingSupplierDebts = false;
  String? _supplierDebtsError;

  // Getters
  List<CustomerDebtModel> get customerDebts => _customerDebts;
  bool get isLoadingCustomerDebts => _isLoadingCustomerDebts;
  String? get customerDebtsError => _customerDebtsError;

  List<SupplierDebtModel> get supplierDebts => _supplierDebts;
  bool get isLoadingSupplierDebts => _isLoadingSupplierDebts;
  String? get supplierDebtsError => _supplierDebtsError;

  int get pendingDebtPaymentsCount => _pendingDebtPaymentsCount;
  bool get isSyncingPendingDebtPayments => _isSyncingPendingDebtPayments;
  String? get lastOperationMessage => _lastOperationMessage;

  void _initializeConnectivityListener() {
    _connectivitySubscription = _connectivityService.onConnectionChanged.listen(
      (hasConnection) async {
        if (hasConnection) {
          // Интернет восстановлен — сначала синкаем офлайн-долги (создание),
          // затем платежи (чтобы было куда применять).
          await syncPendingDebts();
          await syncPendingDebtPayments();
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshPendingDebtPaymentsCount() async {
    _pendingDebtPaymentsCount = await getPendingDebtPaymentsCount();
    notifyListeners();
  }

  Future<int> getPendingDebtPaymentsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_pendingDebtPaymentsKey);
      if (jsonStr == null) return 0;
      final list = jsonDecode(jsonStr) as List;
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _enqueueDebtPayment({
    required String kind, // 'customer' | 'supplier'
    required int debtId,
    required double amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingDebtPaymentsKey);
    final List<dynamic> queue = jsonStr != null ? (jsonDecode(jsonStr) as List) : [];
    queue.add({
      'kind': kind,
      'debtId': debtId,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_pendingDebtPaymentsKey, jsonEncode(queue));
    _pendingDebtPaymentsCount = queue.length;
    notifyListeners();
  }

  Future<void> _savePendingDebtPayments(List<dynamic> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(_pendingDebtPaymentsKey);
      _pendingDebtPaymentsCount = 0;
    } else {
      await prefs.setString(_pendingDebtPaymentsKey, jsonEncode(items));
      _pendingDebtPaymentsCount = items.length;
    }
    notifyListeners();
  }

  Future<void> _cacheCustomerDebts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customerDebts
          .map((d) => {
                'id': d.id,
                'customerName': d.customerName,
                'phone': d.phone,
                'amount': d.amount,
                'paidAmount': d.paidAmount,
                'remainingAmount': d.remainingAmount,
                'description': d.description,
                'debtDate': d.debtDate.toIso8601String(),
                'shopId': d.shopId,
                'userId': d.userId,
              })
          .toList();
      await prefs.setString(_cachedCustomerDebtsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _cacheSupplierDebts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _supplierDebts
          .map((d) => {
                'id': d.id,
                'supplierName': d.supplierName,
                'totalDebt': d.totalDebt,
                'paidAmount': d.paidAmount,
                'remainingAmount': d.remainingAmount,
                'shopId': d.shopId,
                'userId': d.userId,
              })
          .toList();
      await prefs.setString(_cachedSupplierDebtsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<bool> _loadCustomerDebtsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cachedCustomerDebtsKey);
      if (jsonStr == null) return false;
      final list = jsonDecode(jsonStr) as List;
      _customerDebts = list.map((j) => CustomerDebtModel.fromJson(j as Map<String, dynamic>)).toList();
      return _customerDebts.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadSupplierDebtsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cachedSupplierDebtsKey);
      if (jsonStr == null) return false;
      final list = jsonDecode(jsonStr) as List;
      _supplierDebts = list.map((j) => SupplierDebtModel.fromJson(j as Map<String, dynamic>)).toList();
      return _supplierDebts.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enqueueCustomerDebt(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingCustomerDebtsKey);
    final List<dynamic> queue = jsonStr != null ? (jsonDecode(jsonStr) as List) : [];
    queue.add(payload);
    await prefs.setString(_pendingCustomerDebtsKey, jsonEncode(queue));
  }

  Future<void> _enqueueSupplierDebt(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingSupplierDebtsKey);
    final List<dynamic> queue = jsonStr != null ? (jsonDecode(jsonStr) as List) : [];
    queue.add(payload);
    await prefs.setString(_pendingSupplierDebtsKey, jsonEncode(queue));
  }

  bool _isTempId(int id) => id > 1000000000; // timestamp-like

  Future<void> _saveDebtIdMapping({
    required String kind, // customer|supplier
    required int tempId,
    required int realId,
  }) async {
    final key = kind == 'customer' ? _customerDebtIdMappingKey : _supplierDebtIdMappingKey;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    final map = <String, dynamic>{};
    if (jsonStr != null && jsonStr.trim().isNotEmpty) {
      try {
        map.addAll(Map<String, dynamic>.from(jsonDecode(jsonStr) as Map));
      } catch (_) {}
    }
    map[tempId.toString()] = realId;
    await prefs.setString(key, jsonEncode(map));
  }

  Future<int?> _resolveDebtId({
    required String kind, // customer|supplier
    required int id,
  }) async {
    if (!_isTempId(id)) return id;

    final key = kind == 'customer' ? _customerDebtIdMappingKey : _supplierDebtIdMappingKey;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map;
      final real = map[id.toString()];
      if (real == null) return null;
      if (real is num) return real.toInt();
      return int.tryParse(real.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> syncPendingDebts() async {
    // синхронизируем офлайн-долги (создание)
    try {
      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) return;

      final prefs = await SharedPreferences.getInstance();
      final customerStr = prefs.getString(_pendingCustomerDebtsKey);
      final supplierStr = prefs.getString(_pendingSupplierDebtsKey);

      bool syncedCustomerAny = false;
      bool syncedSupplierAny = false;

      if (customerStr != null) {
        final queue = jsonDecode(customerStr) as List;
        final failed = <dynamic>[];
        for (final entry in queue) {
          try {
            // Форматы:
            // - новый: { tempId: 123, payload: {...} }
            // - старый: { ...payload... }
            final map = Map<String, dynamic>.from(entry as Map);
            final tempId = (map['tempId'] is num)
                ? (map['tempId'] as num).toInt()
                : int.tryParse(map['tempId']?.toString() ?? '');
            final payloadRaw = map.containsKey('payload') ? map['payload'] : map;
            final payload = Map<String, dynamic>.from(payloadRaw as Map);

            final response = await _apiService.post(AppConfig.customerDebtsEndpoint, data: payload);
            final ok = response.statusCode == 200 || response.statusCode == 201;
            if (!ok) {
              failed.add(entry);
            } else {
              syncedCustomerAny = true;
              // сохраняем маппинг tempId -> realId, чтобы платежи по офлайн-долгу синкались
              final data = response.data;
              final realId = (data is Map)
                  ? ((data['id'] is num) ? (data['id'] as num).toInt() : int.tryParse(data['id']?.toString() ?? ''))
                  : null;
              if (tempId != null && realId != null) {
                await _saveDebtIdMapping(kind: 'customer', tempId: tempId, realId: realId);
              }
            }
          } catch (_) {
            failed.add(entry);
          }
        }
        if (failed.isEmpty) {
          await prefs.remove(_pendingCustomerDebtsKey);
        } else {
          await prefs.setString(_pendingCustomerDebtsKey, jsonEncode(failed));
        }
      }

      if (supplierStr != null) {
        final queue = jsonDecode(supplierStr) as List;
        final failed = <dynamic>[];
        for (final entry in queue) {
          try {
            final map = Map<String, dynamic>.from(entry as Map);
            final tempId = (map['tempId'] is num)
                ? (map['tempId'] as num).toInt()
                : int.tryParse(map['tempId']?.toString() ?? '');
            final payloadRaw = map.containsKey('payload') ? map['payload'] : map;
            final payload = Map<String, dynamic>.from(payloadRaw as Map);

            final response = await _apiService.post(AppConfig.supplierDebtsEndpoint, data: payload);
            final ok = response.statusCode == 200 || response.statusCode == 201;
            if (!ok) {
              failed.add(entry);
            } else {
              syncedSupplierAny = true;
              final data = response.data;
              final realId = (data is Map)
                  ? ((data['id'] is num) ? (data['id'] as num).toInt() : int.tryParse(data['id']?.toString() ?? ''))
                  : null;
              if (tempId != null && realId != null) {
                await _saveDebtIdMapping(kind: 'supplier', tempId: tempId, realId: realId);
              }
            }
          } catch (_) {
            failed.add(entry);
          }
        }
        if (failed.isEmpty) {
          await prefs.remove(_pendingSupplierDebtsKey);
        } else {
          await prefs.setString(_pendingSupplierDebtsKey, jsonEncode(failed));
        }
      }

      if (syncedCustomerAny) {
        await loadCustomerDebts();
      }
      if (syncedSupplierAny) {
        await loadSupplierDebts();
      }
    } catch (_) {}
  }

  Future<void> syncPendingDebtPayments() async {
    if (_isSyncingPendingDebtPayments) return;

    _isSyncingPendingDebtPayments = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_pendingDebtPaymentsKey);
      if (jsonStr == null) return;

      final queue = jsonDecode(jsonStr) as List;
      if (queue.isEmpty) return;

      final failed = <dynamic>[];
      bool syncedAnyCustomer = false;
      bool syncedAnySupplier = false;

      for (final entry in queue) {
        try {
          final map = Map<String, dynamic>.from(entry as Map);
          final kind = map['kind']?.toString();
          final debtId = (map['debtId'] is num)
              ? (map['debtId'] as num).toInt()
              : int.tryParse(map['debtId']?.toString() ?? '');
          final amount = (map['amount'] is num)
              ? (map['amount'] as num).toDouble()
              : double.tryParse(map['amount']?.toString() ?? '');

          if (kind == null || debtId == null || amount == null) {
            failed.add(entry);
            continue;
          }

          // Если это платеж по офлайн-долгу (tempId), ждём пока долг синкнется и появится маппинг.
          final realDebtId = await _resolveDebtId(kind: kind, id: debtId);
          if (realDebtId == null) {
            failed.add(entry);
            continue;
          }

          final endpoint = kind == 'customer'
              ? '${AppConfig.customerDebtsEndpoint}/$realDebtId/payment'
              : '${AppConfig.supplierDebtsEndpoint}/$realDebtId/payment';

          final response = await _apiService.post(endpoint, data: {'amount': amount});

          final ok = response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
          if (!ok) {
            failed.add(entry);
            continue;
          }

          if (kind == 'customer') syncedAnyCustomer = true;
          if (kind == 'supplier') syncedAnySupplier = true;
        } catch (_) {
          failed.add(entry);
        }
      }

      await _savePendingDebtPayments(failed);

      // Обновляем списки только если реально что-то синкнули
      if (syncedAnyCustomer) {
        await loadCustomerDebts();
      }
      if (syncedAnySupplier) {
        await loadSupplierDebts();
      }
    } finally {
      _isSyncingPendingDebtPayments = false;
      notifyListeners();
    }
  }

  void _applyLocalCustomerPayment(int debtId, double amount) {
    final idx = _customerDebts.indexWhere((d) => d.id == debtId);
    if (idx < 0) return;
    final d = _customerDebts[idx];
    final newPaid = d.paidAmount + amount;
    final newRemaining = (d.remainingAmount - amount) < 0 ? 0.0 : (d.remainingAmount - amount);
    _customerDebts[idx] = CustomerDebtModel(
      id: d.id,
      customerName: d.customerName,
      amount: d.amount,
      paidAmount: newPaid,
      remainingAmount: newRemaining,
      description: d.description,
      debtDate: d.debtDate,
      shopId: d.shopId,
      userId: d.userId,
    );
  }

  void _applyLocalSupplierPayment(int debtId, double amount) {
    final idx = _supplierDebts.indexWhere((d) => d.id == debtId);
    if (idx < 0) return;
    final d = _supplierDebts[idx];
    final newPaid = d.paidAmount + amount;
    final newRemaining = (d.remainingAmount - amount) < 0 ? 0.0 : (d.remainingAmount - amount);
    _supplierDebts[idx] = SupplierDebtModel(
      id: d.id,
      supplierName: d.supplierName,
      totalDebt: d.totalDebt,
      paidAmount: newPaid,
      remainingAmount: newRemaining,
      shopId: d.shopId,
      userId: d.userId,
    );
  }

  double get totalCustomerDebts => _customerDebts
      .where((d) => d.remainingAmount > 0)
      .fold(0.0, (sum, debt) => sum + debt.remainingAmount);
  double get totalSupplierDebts => _supplierDebts.fold(0.0, (sum, debt) => sum + debt.totalDebt);
  double get totalSupplierPaid => _supplierDebts.fold(0.0, (sum, debt) => sum + debt.paidAmount);
  double get totalSupplierRemaining => totalSupplierDebts - totalSupplierPaid;

  // Load Customer Debts
  Future<void> loadCustomerDebts() async {
    _isLoadingCustomerDebts = true;
    _customerDebtsError = null;
    notifyListeners();

    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        _customerDebtsError = 'Магазин не назначен';
        _isLoadingCustomerDebts = false;
        notifyListeners();
        return;
      }

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        final loaded = await _loadCustomerDebtsFromCache();
        _customerDebtsError = loaded ? null : 'Нет интернета (офлайн режим)';
        return;
      }

      print('📥 Загрузка долгов клиентов...');
      print('   Endpoint: ${AppConfig.customerDebtsEndpoint}');
      print('   ShopId: $shopId');

      final response = await _apiService.get(AppConfig.customerDebtsEndpoint);
      
      print('📥 Ответ сервера (customer-debts):');
      print('   Status Code: ${response.statusCode}');
      print('   Data type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> debtsList;
        
        if (data is List) {
          debtsList = data;
        } else if (data is Map && data.containsKey('data')) {
          debtsList = data['data'] as List;
        } else {
          debtsList = [];
        }
        
        _customerDebts = debtsList.map((json) => CustomerDebtModel.fromJson(json)).toList();
        await _cacheCustomerDebts();
        _customerDebtsError = null;
        print('✅ Загружено долгов клиентов: ${_customerDebts.length}');
      } else {
        _customerDebtsError = 'Ошибка загрузки долгов клиентов (${response.statusCode})';
        print('❌ Ошибка: ${response.statusCode} - ${response.data}');
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка загрузки долгов клиентов:');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      
      String errorMessage = 'Ошибка загрузки долгов';
      try {
        final dioError = e as dynamic;
        if (dioError.response != null) {
          final statusCode = dioError.response.statusCode;
          final responseData = dioError.response.data;
          
          if (statusCode == 404) {
            errorMessage = 'Endpoint не найден. Проверьте, что backend запущен и endpoint правильный.';
          } else if (statusCode == 400) {
            errorMessage = 'Неверный запрос. Проверьте данные.';
            if (responseData is Map) {
              errorMessage = responseData['message'] ?? errorMessage;
            }
          } else if (statusCode == 401) {
            errorMessage = 'Не авторизован. Войдите заново.';
          } else if (responseData is Map) {
            errorMessage = responseData['message'] ?? 
                          (responseData['error'] ?? dioError.response.statusMessage ?? errorMessage);
          } else {
            errorMessage = 'Ошибка сервера: $statusCode';
          }
        } else {
          errorMessage = dioError.message?.toString() ?? 'Ошибка сети: ${e.toString()}';
        }
      } catch (_) {
        errorMessage = 'Ошибка: ${e.toString()}';
      }
      
      // При сетевой ошибке показываем кеш, а не красный экран
      final loaded = await _loadCustomerDebtsFromCache();
      _customerDebtsError = loaded ? null : errorMessage;
    } finally {
      _isLoadingCustomerDebts = false;
      notifyListeners();
    }
  }

  // Create Customer Debt
  Future<bool> createCustomerDebt({
    required String customerName,
    String? phone,
    required double amount,
    String? description,
    required DateTime debtDate,
  }) async {
    try {
      _customerDebtsError = null;
      _lastOperationMessage = null;
      notifyListeners();

      // Запрещаем добавлять 2 клиента с одним именем
      final normalized = _normalizeCustomerName(customerName);
      final duplicate = _customerDebts.any((d) => _normalizeCustomerName(d.customerName) == normalized);
      if (duplicate) {
        _customerDebtsError = 'Клиент с таким именем уже существует';
        notifyListeners();
        return false;
      }

      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        _customerDebtsError = 'Магазин не назначен';
        notifyListeners();
        return false;
      }

      final debt = CustomerDebtModel(
        customerName: customerName,
        phone: phone,
        amount: amount,
        description: description,
        debtDate: debtDate,
        shopId: shopId,
        userId: 0, // Будет установлен на сервере
      );

      final debtJson = debt.toJson();
      print('📤 Отправка долга клиента на сервер:');
      print('   Endpoint: ${AppConfig.customerDebtsEndpoint}');
      print('   Data: $debtJson');
      print('   ShopId: $shopId');

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        // ОФЛАЙН: сохраняем локально и в очередь синхронизации
        final tempId = DateTime.now().millisecondsSinceEpoch;
        _customerDebts.insert(
          0,
          CustomerDebtModel(
            id: tempId,
            customerName: customerName,
            phone: phone,
            amount: amount,
            paidAmount: 0.0,
            remainingAmount: amount,
            description: description,
            debtDate: debtDate,
            shopId: shopId,
            userId: 0,
          ),
        );
        await _cacheCustomerDebts();
        await _enqueueCustomerDebt({'tempId': tempId, 'payload': debtJson});
        _lastOperationMessage = 'Долг сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      }

      final response = await _apiService.post(AppConfig.customerDebtsEndpoint, data: debtJson);

      print('📥 Ответ сервера:');
      print('   Status Code: ${response.statusCode}');
      print('   Data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Долг клиента успешно создан: ${response.data}');
        // Перезагружаем список
        await loadCustomerDebts();
        _lastOperationMessage = 'Долг успешно добавлен';
        return true;
      } else {
        print('❌ Ошибка создания долга: ${response.statusCode} - ${response.data}');
        final errorMessage = response.data is Map 
            ? (response.data['message'] ?? response.data.toString())
            : response.data.toString();
        _customerDebtsError = errorMessage;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка создания долга клиента:');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      
      String errorMessage = 'Ошибка создания долга';
      try {
        final dioError = e as dynamic;
        if (dioError.response != null) {
          final responseData = dioError.response.data;
          if (responseData is Map) {
            errorMessage = responseData['message'] ?? 
                          (responseData['error'] ?? dioError.response.statusMessage ?? errorMessage);
          } else {
            errorMessage = responseData.toString();
          }
        } else {
          errorMessage = dioError.message?.toString() ?? 'Ошибка сети';
        }
      } catch (_) {
        errorMessage = e.toString();
      }
      
      // Ошибка сети — сохраняем офлайн (как успешную операцию)
      try {
        final shopId = await _storageService.getShopId();
        if (shopId != null) {
          final tempId = DateTime.now().millisecondsSinceEpoch;
          final debt = CustomerDebtModel(
            id: tempId,
            customerName: customerName,
            phone: phone,
            amount: amount,
            paidAmount: 0.0,
            remainingAmount: amount,
            description: description,
            debtDate: debtDate,
            shopId: shopId,
            userId: 0,
          );
          final debtJson = debt.toJson();
          _customerDebts.insert(0, debt);
          await _cacheCustomerDebts();
          await _enqueueCustomerDebt({'tempId': tempId, 'payload': debtJson});
          _lastOperationMessage = 'Долг сохранён офлайн. Синхронизация при появлении интернета.';
          notifyListeners();
          return true;
        }
      } catch (_) {}

      _customerDebtsError = errorMessage;
      notifyListeners();
      return false;
    }
  }

  // Load Supplier Debts
  Future<void> loadSupplierDebts() async {
    _isLoadingSupplierDebts = true;
    _supplierDebtsError = null;
    notifyListeners();

    try {
      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        _supplierDebtsError = 'Магазин не назначен';
        _isLoadingSupplierDebts = false;
        notifyListeners();
        return;
      }

      print('📥 Загрузка долгов фирмам...');
      print('   Endpoint: ${AppConfig.supplierDebtsEndpoint}');
      print('   ShopId: $shopId');

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        final loaded = await _loadSupplierDebtsFromCache();
        _supplierDebtsError = loaded ? null : 'Нет интернета (офлайн режим)';
        return;
      }

      final response = await _apiService.get(AppConfig.supplierDebtsEndpoint);
      
      print('📥 Ответ сервера (supplier-debts):');
      print('   Status Code: ${response.statusCode}');
      print('   Data type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> debtsList;
        
        if (data is List) {
          debtsList = data;
        } else if (data is Map && data.containsKey('data')) {
          debtsList = data['data'] as List;
        } else {
          debtsList = [];
        }
        
        // Защита от дубликатов (иногда бэк может вернуть повторяющиеся записи).
        // DropdownButton падает, если в items есть 2 одинаковых value.
        final parsed = debtsList.map((json) => SupplierDebtModel.fromJson(json)).toList();
        final seen = <int, SupplierDebtModel>{};
        final ordered = <SupplierDebtModel>[];
        for (final d in parsed) {
          final id = d.id;
          if (id == null) {
            ordered.add(d);
            continue;
          }
          if (!seen.containsKey(id)) {
            seen[id] = d;
            ordered.add(d);
          } else {
            // Если повтор — обновляем запись в map, но порядок не ломаем
            seen[id] = d;
          }
        }
        // Подменяем элементы в ordered на "последнюю версию" из map (если были повторы)
        _supplierDebts = ordered.map((d) => d.id != null ? (seen[d.id!] ?? d) : d).toList();
        await _cacheSupplierDebts();
        _supplierDebtsError = null;
        print('✅ Загружено долгов фирмам: ${_supplierDebts.length}');
      } else {
        _supplierDebtsError = 'Ошибка загрузки долгов фирмам (${response.statusCode})';
        print('❌ Ошибка: ${response.statusCode} - ${response.data}');
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка загрузки долгов фирмам:');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      
      String errorMessage = 'Ошибка загрузки долгов';
      try {
        final dioError = e as dynamic;
        if (dioError.response != null) {
          final statusCode = dioError.response.statusCode;
          final responseData = dioError.response.data;
          
          if (statusCode == 404) {
            errorMessage = 'Endpoint не найден. Проверьте, что backend запущен и endpoint правильный.';
          } else if (statusCode == 400) {
            errorMessage = 'Неверный запрос. Проверьте данные.';
            if (responseData is Map) {
              errorMessage = responseData['message'] ?? errorMessage;
            }
          } else if (statusCode == 401) {
            errorMessage = 'Не авторизован. Войдите заново.';
          } else if (responseData is Map) {
            errorMessage = responseData['message'] ?? 
                          (responseData['error'] ?? dioError.response.statusMessage ?? errorMessage);
          } else {
            errorMessage = 'Ошибка сервера: $statusCode';
          }
        } else {
          errorMessage = dioError.message?.toString() ?? 'Ошибка сети: ${e.toString()}';
        }
      } catch (_) {
        errorMessage = 'Ошибка: ${e.toString()}';
      }
      
      final loaded = await _loadSupplierDebtsFromCache();
      _supplierDebtsError = loaded ? null : errorMessage;
    } finally {
      _isLoadingSupplierDebts = false;
      notifyListeners();
    }
  }

  // Create Supplier Debt
  Future<bool> createSupplierDebt({
    required String supplierName,
    required double totalDebt,
    double paidAmount = 0.0,
  }) async {
    try {
      _supplierDebtsError = null;
      _lastOperationMessage = null;
      notifyListeners();

      final shopId = await _storageService.getShopId();
      if (shopId == null) {
        _supplierDebtsError = 'Магазин не назначен';
        notifyListeners();
        return false;
      }

      final debt = SupplierDebtModel(
        supplierName: supplierName,
        totalDebt: totalDebt,
        paidAmount: paidAmount,
        shopId: shopId,
        userId: 0, // Будет установлен на сервере
      );

      final debtJson = debt.toJson();
      print('📤 Отправка долга фирме на сервер:');
      print('   Endpoint: ${AppConfig.supplierDebtsEndpoint}');
      print('   Data: $debtJson');
      print('   ShopId: $shopId');

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        final tempId = DateTime.now().millisecondsSinceEpoch;
        _supplierDebts.insert(
          0,
          SupplierDebtModel(
            id: tempId,
            supplierName: supplierName,
            totalDebt: totalDebt,
            paidAmount: paidAmount,
            remainingAmount: totalDebt - paidAmount,
            shopId: shopId,
            userId: 0,
          ),
        );
        await _cacheSupplierDebts();
        await _enqueueSupplierDebt({'tempId': tempId, 'payload': debtJson});
        _lastOperationMessage = 'Долг сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      }

      final response = await _apiService.post(AppConfig.supplierDebtsEndpoint, data: debtJson);

      print('📥 Ответ сервера:');
      print('   Status Code: ${response.statusCode}');
      print('   Data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Долг фирме успешно создан: ${response.data}');
        // Перезагружаем список
        await loadSupplierDebts();
        _lastOperationMessage = 'Долг успешно добавлен';
        return true;
      } else {
        print('❌ Ошибка создания долга фирме: ${response.statusCode} - ${response.data}');
        final errorMessage = response.data is Map 
            ? (response.data['message'] ?? response.data.toString())
            : response.data.toString();
        _supplierDebtsError = errorMessage;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка создания долга фирме:');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      
      String errorMessage = 'Ошибка создания долга';
      try {
        final dioError = e as dynamic;
        if (dioError.response != null) {
          final responseData = dioError.response.data;
          if (responseData is Map) {
            errorMessage = responseData['message'] ?? 
                          (responseData['error'] ?? dioError.response.statusMessage ?? errorMessage);
          } else {
            errorMessage = responseData.toString();
          }
        } else {
          errorMessage = dioError.message?.toString() ?? 'Ошибка сети';
        }
      } catch (_) {
        errorMessage = e.toString();
      }
      
      // Ошибка сети — сохраняем офлайн (как успешную операцию)
      try {
        final shopId = await _storageService.getShopId();
        if (shopId != null) {
          final tempId = DateTime.now().millisecondsSinceEpoch;
          final debt = SupplierDebtModel(
            id: tempId,
            supplierName: supplierName,
            totalDebt: totalDebt,
            paidAmount: paidAmount,
            remainingAmount: totalDebt - paidAmount,
            shopId: shopId,
            userId: 0,
          );
          final debtJson = debt.toJson();
          _supplierDebts.insert(0, debt);
          await _cacheSupplierDebts();
          await _enqueueSupplierDebt({'tempId': tempId, 'payload': debtJson});
          _lastOperationMessage = 'Долг сохранён офлайн. Синхронизация при появлении интернета.';
          notifyListeners();
          return true;
        }
      } catch (_) {}

      _supplierDebtsError = errorMessage;
      notifyListeners();
      return false;
    }
  }

  // Add Payment to Customer Debt
  Future<bool> addPaymentToCustomerDebt(int debtId, double amount) async {
    try {
      // Сбрасываем прошлую ошибку, чтобы экран не зависал в error-state
      _customerDebtsError = null;
      _lastOperationMessage = null;
      notifyListeners();

      print('📤 Добавление платежа к долгу клиента $debtId: $amount');

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        await _enqueueDebtPayment(kind: 'customer', debtId: debtId, amount: amount);
        _applyLocalCustomerPayment(debtId, amount);
        _lastOperationMessage = 'Платеж сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      }

      final response = await _apiService.post(
        '${AppConfig.customerDebtsEndpoint}/$debtId/payment',
        data: {'amount': amount},
      );

      // NestJS по умолчанию для POST возвращает 201.
      // Также допускаем 204 (no content), если бэк так настроен.
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        print('✅ Платеж успешно добавлен: ${response.data}');
        // Перезагружаем список
        await loadCustomerDebts();
        _lastOperationMessage = 'Платеж успешно добавлен';
        return true;
      } else {
        print('❌ Ошибка добавления платежа: ${response.statusCode} - ${response.data}');
        _customerDebtsError = response.data is Map 
            ? (response.data['message'] ?? 'Ошибка добавления платежа')
            : 'Ошибка добавления платежа';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Ошибка добавления платежа: $e');
      // Ошибка сети — сохраняем офлайн и не пугаем пользователя
      try {
        await _enqueueDebtPayment(kind: 'customer', debtId: debtId, amount: amount);
        _applyLocalCustomerPayment(debtId, amount);
        _lastOperationMessage = 'Платеж сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      } catch (_) {
        _customerDebtsError = 'Ошибка: ${e.toString()}';
        notifyListeners();
        return false;
      }
    }
  }

  // Add Payment to Supplier Debt
  Future<bool> addPaymentToSupplierDebt(int debtId, double amount) async {
    try {
      // Сбрасываем прошлую ошибку, чтобы экран не зависал в error-state
      _supplierDebtsError = null;
      _lastOperationMessage = null;
      notifyListeners();

      print('📤 Добавление платежа к долгу $debtId: $amount');

      final hasInternet = await _connectivityService.hasInternetConnection();
      if (!hasInternet) {
        await _enqueueDebtPayment(kind: 'supplier', debtId: debtId, amount: amount);
        _applyLocalSupplierPayment(debtId, amount);
        _lastOperationMessage = 'Платеж сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      }

      final response = await _apiService.post(
        '${AppConfig.supplierDebtsEndpoint}/$debtId/payment',
        data: {'amount': amount},
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        print('✅ Платеж успешно добавлен: ${response.data}');
        // Перезагружаем список
        await loadSupplierDebts();
        _lastOperationMessage = 'Платеж успешно добавлен';
        return true;
      } else {
        print('❌ Ошибка добавления платежа: ${response.statusCode} - ${response.data}');
        _supplierDebtsError = response.data is Map
            ? (response.data['message'] ?? 'Ошибка добавления платежа')
            : 'Ошибка добавления платежа';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Ошибка добавления платежа: $e');
      // Ошибка сети — сохраняем офлайн и не пугаем пользователя
      try {
        await _enqueueDebtPayment(kind: 'supplier', debtId: debtId, amount: amount);
        _applyLocalSupplierPayment(debtId, amount);
        _lastOperationMessage = 'Платеж сохранён офлайн. Синхронизация при появлении интернета.';
        notifyListeners();
        return true;
      } catch (_) {
        _supplierDebtsError = 'Ошибка: ${e.toString()}';
        notifyListeners();
        return false;
      }
    }
  }
}
