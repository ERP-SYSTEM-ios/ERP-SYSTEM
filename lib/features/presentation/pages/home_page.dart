import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? name;
  String? surname;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No logged-in user.");
      }

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          name = userDoc.get("name");
          surname = userDoc.get("surname");
          isLoading = false;
        });
      } else {
        throw Exception("Kullanıcı belgesi mevcut değil.");
      }
    } catch (e) {
      print("Hata: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    bool confirmSignOut = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Çıkış"),
          content: const Text("Çıkış yapmak istediğinizden emin misiniz?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Çıkış"),
            ),
          ],
        );
      },
    );

    if (confirmSignOut) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata olustu: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
              ),
              accountName: Text(
                name ?? "User",
                style: const TextStyle(fontSize: 18),
              ),
              accountEmail: surname != null ? Text(surname!) : const Text(""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Gösterge Paneli'),
              onTap: () {
                Navigator.pushNamed(context, '/dashboard'); // Navigate to DashboardPage
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Sipariş ekle'),
              onTap: () {
                Navigator.pushNamed(context, '/make_order');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Siparişlerim'),
              onTap: () {
                Navigator.pushNamed(context, '/ordersCart');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Ürünlerim'),
              onTap: () {
                Navigator.pushNamed(context, '/productsInfo');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warehouse),
              title: const Text('Hammadde Deposu'),
              onTap: () {
                Navigator.pushNamed(
                    context, '/warehouse'); // Navigate to WarehousePage
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Müşterilerim'),
              onTap: () {
                Navigator.pushNamed(
                    context, '/customers'); // Navigate to CustomersPage
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Çıkış',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : name != null && surname != null
                ? Text(
                    "Hoş Geldiniz $name $surname",
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  )
                : const Text(
                    "Hoş Geldiniz!",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
      ),
    );
  }
}
