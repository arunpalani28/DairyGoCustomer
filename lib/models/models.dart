// ── Data Models for Customer App ─────────────────────────────────────────────

class UserProfile {
  final int id;
  final String name, email, phone, kycStatus, zone;
  final double walletBalance;
  final bool autoRecharge;

  UserProfile.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        name = j['name'] ?? '',
        email = j['email'] ?? '',
        phone = j['phone'] ?? '',
        kycStatus = j['kycStatus'] ?? 'PENDING',
        zone = j['zone'] ?? '',
        walletBalance = (j['walletBalance'] as num?)?.toDouble() ?? 0.0,
        autoRecharge = j['autoRecharge'] ?? true;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'RK';
  }
}

class SubscriptionModel {
  final int id;
  final String planName;
  final int quantityMl;
  final double pricePerDay;
  final bool isActive;
  final String startDate;

  SubscriptionModel.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        planName = j['planName'] ?? 'Full Cream Milk',
        quantityMl = j['quantityMl'] ?? 500,
        pricePerDay = (j['pricePerDay'] as num?)?.toDouble() ?? 24.0,
        isActive = j['isActive'] ?? true,
        startDate = j['startDate'] ?? '';
}

class DeliveryDay {
  final int id;
  final String deliveryDate, status;
  final int quantityMl;
  final bool isExtra;
  final double extraFee;
  final String driverName;

  DeliveryDay.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        deliveryDate = j['deliveryDate'] ?? '',
        status = j['status'] ?? 'PENDING',
        quantityMl = j['quantityMl'] ?? 500,
        isExtra = j['isExtra'] ?? false,
        extraFee = (j['extraFee'] as num?)?.toDouble() ?? 0.0,
        driverName = j['driverName'] ?? '';
}

class Product {
  final int id;
  final String name, emoji, weightLabel, category;
  final double price;
  final int stockQty;

  Product.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        name = j['name'] ?? '',
        emoji = j['emoji'] ?? '🥛',
        weightLabel = j['weightLabel'] ?? '',
        category = j['category'] ?? '',
        price = (j['price'] as num?)?.toDouble() ?? 0.0,
        stockQty = j['stockQty'] ?? 0;
}

class Bill {
  final int id, billMonth, billYear;
  final double subscriptionAmount, oneTimeAmount, extraDeliveryAmount, deliveryCharges, totalAmount;
  final String status;

  Bill.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        billMonth = j['billMonth'] ?? 0,
        billYear = j['billYear'] ?? 0,
        subscriptionAmount = (j['subscriptionAmount'] as num?)?.toDouble() ?? 0.0,
        oneTimeAmount = (j['oneTimeAmount'] as num?)?.toDouble() ?? 0.0,
        extraDeliveryAmount = (j['extraDeliveryAmount'] as num?)?.toDouble() ?? 0.0,
        deliveryCharges = (j['deliveryCharges'] as num?)?.toDouble() ?? 0.0,
        totalAmount = (j['totalAmount'] as num?)?.toDouble() ?? 0.0,
        status = j['status'] ?? 'GENERATED';

  String get monthName =>
      ['', 'January', 'February', 'March', 'April', 'May', 'June',
       'July', 'August', 'September', 'October', 'November', 'December'][billMonth];
}

class WalletTx {
  final int id;
  final String type, description, createdAt;
  final double amount;

  WalletTx.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        type = j['type'] ?? 'DEBIT',
        description = j['description'] ?? '',
        createdAt = j['createdAt'] ?? '',
        amount = (j['amount'] as num?)?.toDouble() ?? 0.0;

  bool get isCredit => type == 'CREDIT';
  bool get isExtraFee => description.toLowerCase().contains('extra');
  String get shortDate => createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
}

class PauseItem {
  final int id;
  final String fromDate, toDate, reason, status;

  PauseItem.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        fromDate = j['fromDate'] ?? '',
        toDate = j['toDate'] ?? '',
        reason = j['reason'] ?? '',
        status = j['status'] ?? 'APPROVED';
}

class OrderItemDetail {
  final int id;
  final String name, emoji;
  final int qty;
  final double unitPrice;
  OrderItemDetail.fromJson(Map<String, dynamic> j)
      : id = j['product']?['id'] ?? 0,
        name = j['product']?['name'] ?? '',
        emoji = j['product']?['emoji'] ?? '🛒',
        qty = j['qty'] ?? 1,
        unitPrice = (j['unitPrice'] as num?)?.toDouble() ?? 0.0;
}

class RecentOrder {
  final int id;
  final String status, createdAt;
  final double totalAmount, deliveryCharge, distanceKm;
  final List<OrderItemDetail> items;
  RecentOrder.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        status = j['status'] ?? 'PLACED',
        createdAt = j['createdAt'] ?? '',
        totalAmount = (j['totalAmount'] as num?)?.toDouble() ?? 0.0,
        deliveryCharge = (j['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
        distanceKm = (j['distanceKm'] as num?)?.toDouble() ?? 0.0,
        items = ((j['items'] as List?) ?? []).map((e) => OrderItemDetail.fromJson(e)).toList();
}
