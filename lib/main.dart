import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:erp_system/features/app/splash_screen/splash_screen.dart';
import 'package:erp_system/features/presentation/pages/home_page.dart';
import 'package:erp_system/features/presentation/pages/login_page.dart';
import 'package:erp_system/features/presentation/pages/order_page.dart';
import 'package:erp_system/features/presentation/pages/orders_cart.dart';
import 'package:erp_system/features/presentation/pages/products_info.dart';
import 'package:erp_system/features/presentation/pages/customers_page.dart'; 
import 'package:erp_system/features/presentation/pages/warehouse_page.dart';  
import 'package:erp_system/features/presentation/pages/dashboard_page.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> _fetchCompanyId() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return null; // No user is logged in
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!['companyId'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching companyId: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ERP SYSTEM",
      routes: {
        '/': (context) => const SplashScreen(child: LoginPage()),
        '/home': (context) => const HomePage(),
        '/make_order': (context) => const OrderPage(),
        '/ordersCart': (context) => const OrdersCart(),
        '/productsInfo': (context) => FutureBuilder<String?>(
              future: _fetchCompanyId(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Hata')),
                    body: const Center(
                      child: Text('Şirket bilgisi eksik veya erişilemiyor.'),
                    ),
                  );
                }
                return ProductsPage(companyId: snapshot.data!); // Pass companyId
              },
            ),
        '/login': (context) => const LoginPage(),
        '/customers': (context) => FutureBuilder<String?>(
              future: _fetchCompanyId(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Hata')),
                    body: const Center(
                      child: Text('Şirket bilgisi eksik veya erişilemiyor.'),
                    ),
                  );
                }
                return CustomersPage(companyId: snapshot.data!); // Pass companyId
              },
            ),
        '/warehouse': (context) => FutureBuilder<String?>(
              future: _fetchCompanyId(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Hata')),
                    body: const Center(
                      child: Text('Şirket bilgisi eksik veya erişilemiyor.'),
                    ),
                  );
                }
                return WarehousePage(companyId: snapshot.data!); // Pass companyId
              },
            ),
            '/dashboard': (context) => FutureBuilder<String?>(
      future: _fetchCompanyId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hata')),
            body: const Center(
              child: Text('Şirket bilgisi eksik veya erişilemiyor.'),
            ),
          );
        }
        return const DashboardPage(); // No need to pass the companyId here since DashboardPage fetches it.
      },
    ),

      },
      initialRoute: '/', // Set initial route
    );
  }
}
