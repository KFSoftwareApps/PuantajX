class AppPlans {
  static const free = PlanConfig(
    id: 'free',
    name: 'Ücretsiz',
    maxProjects: 1,
    maxWorkers: 2,
    monthlyPrice: 0,
  );

  static const pro = PlanConfig(
    id: 'pro',
    name: 'Pro',
    maxProjects: 5,
    maxWorkers: 10,
    monthlyPrice: 1490,
  );

  static const business = PlanConfig(
    id: 'business',
    name: 'Business',
    maxProjects: 9999,
    maxWorkers: 25,
    monthlyPrice: 2990,
  );

  static PlanConfig getConfig(String planId) {
    if (planId == 'pro') return pro;
    if (planId == 'business') return business;
    return free;
  }
}

class PlanConfig {
  final String id;
  final String name;
  final int maxProjects;
  final int maxWorkers;
  final double monthlyPrice;

  const PlanConfig({
    required this.id,
    required this.name,
    required this.maxProjects,
    required this.maxWorkers,
    required this.monthlyPrice,
  });
}
