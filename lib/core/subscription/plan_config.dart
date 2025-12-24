import 'package:flutter/material.dart';

/// Subscription plans available in the app
enum SubscriptionPlan {
  free,
  pro,
  business,
}

/// Feature entitlements that can be enabled/disabled per plan
enum Entitlement {
  // Core features
  cloudSync,
  unlimitedHistory,
  
  // Export features
  pdfNoWatermark,
  pdfTemplates,
  excelExport,
  
  // Workflow features
  approvalFlow,
  periodLock,
  auditLog,
  
  // Finance features
  wageRates,
  paymentSummary,
  payAdjustments,
  
  // Admin features
  ownerPolicyPanel,
  roleTemplates,
  userOverrides,
  guestSharing,
}

/// Plan configuration - Single source of truth for all subscription limits and features
class PlanConfig {
  final SubscriptionPlan plan;
  final String displayName;
  final String description;
  final int priceMonthly; // TL cinsinden (kuruş olarak: 999 TL = 99900)
  
  // UI Properties
  final String badgeText;
  final Color accentColor;
  final List<String> featureBullets;

  // Limits
  final int organizationLimit;
  final int projectLimit;
  final int seatLimit;
  final int workerLimit;
  final int storageLimitGB;
  final int retentionDays; // 0 = unlimited
  final int photoLimit; // 0 = unlimited
  
  // Entitlements
  final Set<Entitlement> entitlements;
  
  const PlanConfig({
    required this.plan,
    required this.displayName,
    required this.description,
    required this.priceMonthly,
    required this.badgeText,
    required this.accentColor,
    required this.featureBullets,
    required this.organizationLimit,
    required this.projectLimit,
    required this.seatLimit,
    required this.workerLimit,
    required this.storageLimitGB,
    required this.retentionDays,
    required this.photoLimit,
    required this.entitlements,
  });
  
  bool hasEntitlement(Entitlement entitlement) {
    return entitlements.contains(entitlement);
  }
  
  bool isUnlimited(String limitType) {
    switch (limitType) {
      case 'projects':
        return projectLimit == 0;
      case 'seats':
        return seatLimit == 0;
      case 'workers':
        return workerLimit == 0;
      case 'photos':
        return photoLimit == 0;
      case 'retention':
        return retentionDays == 0;
      default:
        return false;
    }
  }
}

/// All plan configurations
class Plans {
  static const free = PlanConfig(
    plan: SubscriptionPlan.free,
    displayName: 'Free',
    description: 'Tek şantiye, tek cihaz - Deneme için ideal',
    priceMonthly: 0,
    badgeText: 'Başlamak İçin',
    accentColor: Colors.teal,
    featureBullets: [
      'Günlük rapor + puantaj (temel)',
      'Foto/İmza (cihazda)',
      'PDF paylaşım (filigranlı)',
      'Lokal yedekleme',
    ],
    organizationLimit: 1,
    projectLimit: 1,
    seatLimit: 1,
    workerLimit: 20,
    storageLimitGB: 0, // Local only
    retentionDays: 30,
    photoLimit: 200,
    entitlements: {
      // Free has NO premium entitlements
    },
  );
  
  static const pro = PlanConfig(
    plan: SubscriptionPlan.pro,
    displayName: 'Pro',
    description: 'Ekip + Bulut + Profesyonel çıktı',
    priceMonthly: 99900, // ₺999
    badgeText: 'En Popüler',
    accentColor: Colors.blue,
    featureBullets: [
      'Ekipçe kullan, Buluta senkronla',
      'Filigransız PDF + Şablonlar',
      '5 Proje, 10 Kullanıcı',
      '200 Çalışan Sınırı',
      'Sınırsız Geçmiş',
    ],
    organizationLimit: 1,
    projectLimit: 5,
    seatLimit: 10,
    workerLimit: 200,
    storageLimitGB: 10,
    retentionDays: 0, // Unlimited
    photoLimit: 0, // Unlimited
    entitlements: {
      Entitlement.cloudSync,
      Entitlement.unlimitedHistory,
      Entitlement.pdfNoWatermark,
      Entitlement.pdfTemplates,
    },
  );
  
  static const business = PlanConfig(
    plan: SubscriptionPlan.business,
    displayName: 'Business',
    description: 'Kurumsal kontrol: Onay, Kilit, Audit, Finans',
    priceMonthly: 199900, // ₺1.999
    badgeText: 'Güçlü',
    accentColor: Colors.indigo,
    featureBullets: [
      'Her şey sınırsız (Proje, Çalışan)',
      '25 Kullanıcıya kadar',
      'Excel Dışa Aktarım',
      'Onay & Kilit Akışları',
      'Denetim Kayıtları (Audit)',
      'Finans & Bütçe',
    ],
    organizationLimit: 1,
    projectLimit: 0, // Unlimited
    seatLimit: 25,
    workerLimit: 0, // Unlimited
    storageLimitGB: 100,
    retentionDays: 0, // Unlimited
    photoLimit: 0, // Unlimited
    entitlements: {
      // All Pro features
      Entitlement.cloudSync,
      Entitlement.unlimitedHistory,
      Entitlement.pdfNoWatermark,
      Entitlement.pdfTemplates,
      
      // Business-only features
      Entitlement.excelExport,
      Entitlement.approvalFlow,
      Entitlement.periodLock,
      Entitlement.auditLog,
      Entitlement.wageRates,
      Entitlement.paymentSummary,
      Entitlement.payAdjustments,
      Entitlement.ownerPolicyPanel,
      Entitlement.roleTemplates,
      Entitlement.userOverrides,
      Entitlement.guestSharing,
    },
  );
  
  static PlanConfig getConfig(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return free;
      case SubscriptionPlan.pro:
        return pro;
      case SubscriptionPlan.business:
        return business;
    }
  }
  
  static List<PlanConfig> allPlans = [free, pro, business];
}
