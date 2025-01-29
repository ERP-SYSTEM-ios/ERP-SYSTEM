import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomersPage extends StatefulWidget {
  final String companyId; // Company ID passed dynamically
  const CustomersPage({required this.companyId, super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _extraDetailsController = TextEditingController();

  // Function to add customer
  Future<void> _addCustomer() async {
    if (_companyNameController.text.isEmpty ||
        _managerNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _extraDetailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    try {
      final customer = {
        'companyName': _companyNameController.text,
        'managerName': _managerNameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'extraDetails': _extraDetailsController.text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add customer to the "customers" subcollection under the company
      await FirebaseFirestore.instance
          .collection('Companies')
          .doc(widget.companyId)
          .collection('customers')
          .add(customer);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müşteri eklendi')),
      );

      // Clear form fields
      _companyNameController.clear();
      _managerNameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _extraDetailsController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Müşteri kaydedilemedi: $e')),
      );
    }
  }

  // Function to show the form to add customer
  void _showAddCustomerForm() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Müşteri Ekle'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Şirket Adı'),
                ),
                TextField(
                  controller: _managerNameController,
                  decoration: const InputDecoration(labelText: 'Yönetici Adı ve Soyadı'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adres'),
                ),
                TextField(
                  controller: _extraDetailsController,
                  decoration: const InputDecoration(labelText: 'Ekstra Detaylar'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                await _addCustomer();
                Navigator.pop(context); // Close the dialog after adding customer
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteriler'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Stream customers from the company's "customers" subcollection
                stream: FirebaseFirestore.instance
                    .collection('Companies')
                    .doc(widget.companyId)
                    .collection('customers')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Henüz müşteri eklenmemiş'),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _showAddCustomerForm,
                            child: const Text('Müşteri Ekle'),
                          ),
                        ],
                      ),
                    );
                  }

                  final customers = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return ListTile(
                        title: Text(customer['companyName']),
                        subtitle: Text(
                          'Yönetici: ${customer['managerName']} - Telefon: ${customer['phone']} - Adres: ${customer['address']}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
