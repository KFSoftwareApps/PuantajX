import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  Stream<List<PurchaseDetails>> get purchaseStream => throw UnimplementedError();
  Future<void> init() => throw UnimplementedError();
  List<ProductDetails> get products => throw UnimplementedError();
  Future<void> buyProduct(ProductDetails product) => throw UnimplementedError();
  Future<void> restorePurchases() => throw UnimplementedError();
  dynamic checkEntitlement(List<PurchaseDetails> purchases) => throw UnimplementedError();
}
