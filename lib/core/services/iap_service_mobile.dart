import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../subscription/plan_config.dart';


class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  static const Set<String> _productIds = {
    'puantajx_pro_monthly',
    'puantajx_business_monthly',
  };

  bool _isAvailable = false;
  List<ProductDetails> _products = [];

  Future<void> init() async {
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      await _loadProducts();
    } else {
      debugPrint('IAP not available (Mobile)');
    }
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
    _products = response.productDetails;
    debugPrint('Loaded ${_products.length} products (Mobile)');
  }

  List<ProductDetails> get products => _products;

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  SubscriptionPlan checkEntitlement(List<PurchaseDetails> purchases) {
    bool hasBusiness = false;
    bool hasPro = false;

    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (purchase.productID.contains('business')) {
           hasBusiness = true;
        } else if (purchase.productID.contains('pro')) {
           hasPro = true;
        }
        
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }

    if (hasBusiness) return SubscriptionPlan.business;
    if (hasPro) return SubscriptionPlan.pro;
    return SubscriptionPlan.free;
  }
}
