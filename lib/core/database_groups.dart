/// أسماء مسارات Firebase Realtime Database المستخدمة في المشروع.
/// ملاحظة: تعريف المسارات لا ينشئ عقدًا في Firebase؛ تظهر بعد كتابة بيانات.
class DatabaseGroups {
  DatabaseGroups._();

  // الحسابات
  static const String users = 'users';
  static const String drivers = 'drivers';

  // الرحلات والعروض
  static const String rides = 'rides';
  static const String rideOffers = 'ride_offers'; // مسار مستقل قديم/اختياري
  static const String rideOffersChild = 'offers'; // rides/{rideId}/offers
  static const String userRides = 'userRides';
  static const String driverTrips = 'driverTrips';
  static const String openRequests = 'openRequests';

  // المحافظ والمدفوعات
  static const String wallets = 'wallets';
  static const String transactions = 'transactions';
  static const String payoutRequests = 'payoutRequests';
  static const String walletTopups = 'topups';
  static const String processedOperations = 'processedOperations';

  // التواصل والإشعارات والتقييمات
  static const String notifications = 'notifications';
  static const String broadcasts = 'broadcasts';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String ratings = 'ratings';
  static const String driverRatings = 'driverRatings';

  // الدعم والإدارة والإعدادات
  static const String supportTickets = 'support_tickets';
  static const String tickets = 'tickets';
  static const String settings = 'settings';
  static const String adminLogs = 'admin_logs';
  static const String pricing = 'pricing';
  static const String commissionPercent = 'commissionPercent';
  static const String uploadApi = 'uploadApi';

  // حالة السائق والموقع
  static const String onlineDrivers = 'onlineDrivers';
  static const String driverActive = 'driverActive';
  static const String driverLocations = 'driverLocations';

  // المناطق
  static const String serviceZones = 'serviceZones';
  static const String zones = 'zones';

  // حقول فرعية متكررة
  static const String activeRide = 'activeRide';
  static const String online = 'online';
  static const String offers = 'offers';
  static const String status = 'status';
  static const String balance = 'balance';
  static const String read = 'read';
  static const String places = 'places';
  static const String docs = 'docs';
  static const String vehicle = 'vehicle';
  static const String tripsCount = 'tripsCount';
  static const String riderScore = 'riderScore';
}
