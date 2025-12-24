import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Stub class for Web where IAP is not available
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  // Empty stream
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  Future<void> init() async {
    debugPrint('IAP not supported on Web');
  }

  List<ProductDetails> get products => [];

  Future<void> buyProduct(ProductDetails product) async {
    debugPrint('Buy product called on Web (Not supported)');
  }

  Future<void> restorePurchases() async {
    debugPrint('Restore purchases called on Web (Not supported)');
  }

  dynamic checkEntitlement(List<PurchaseDetails> purchases) {
    return null; 
  }
}
