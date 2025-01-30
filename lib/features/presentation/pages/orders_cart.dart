import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrdersCart extends StatefulWidget {
  const OrdersCart({super.key});

  @override
  State<OrdersCart> createState() => _OrdersCartState();
}

class _OrdersCartState extends State<OrdersCart> {
  String? currentCompanyName;
  bool isAscending = true; // Controls ascending/descending order
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _productTypeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _editingOrderId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserCompany();
  }

  Future<void> _getCurrentUserCompany() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            currentCompanyName = userDoc['companyId'];
          });
        }
      }
    } catch (e) {
      print("Error fetching user company: $e");
    }
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('orders');

    // Apply sorting by order number
    query = query.orderBy('orderNumber', descending: !isAscending);

    return query;
  }

  // Method to start editing the order
  void _editOrder(String orderId, Map<String, dynamic> orderData) {
    setState(() {
      _editingOrderId = orderId;
      _productController.text = orderData['product'];
      _productTypeController.text = orderData['productType'].toString();
      _quantityController.text = orderData['amount'].toString();
      _priceController.text = orderData['pricePerUnit'].toString();
    });
  }

  // Method to save the edited order to Firestore
  Future<void> _updateOrder() async {
    if (_editingOrderId != null) {
      try {
        // First, update the order
        await FirebaseFirestore.instance
            .collection('Companies')
            .doc(currentCompanyName)
            .collection('orders')
            .doc(_editingOrderId)
            .update({
          'product': _productController.text,
          'amount': int.parse(_quantityController.text),
          'pricePerUnit': double.parse(_priceController.text),
          'total': int.parse(_quantityController.text) * double.parse(_priceController.text),
        });

        // Now, update the warehouse stock
        await _updateWarehouseStock();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sipariş başarıyla güncellendi')),
        );

        setState(() {
          _editingOrderId = null;
        });
      } catch (e) {
        print("Error updating order: $e");
      }
    }
  }

  // Method to update the warehouse stock
  Future<void> _updateWarehouseStock() async {
    final productName = _productTypeController.text.trim().toLowerCase();  // Trim spaces from product name
    final orderQuantity = int.parse(_quantityController.text);

    // Print product name to debug
    print("Looking for product: $productName in warehouse.");

    try {
      // Make the query case-insensitive and ignore leading/trailing spaces
      final String trimmedProductName = productName.toLowerCase();

      // Query the 'products' collection to get the 'type' field
      final productSnapshot = await FirebaseFirestore.instance
          .collection('Companies')
          .doc(currentCompanyName)
          .collection('products')
          .where('type', isEqualTo: trimmedProductName)
          .limit(1)
          .get();
      print("productSnapshot  : $productSnapshot");
      print("productSnapshot  : $trimmedProductName");

      if (productSnapshot.docs.isNotEmpty) {
        final productData = productSnapshot.docs.first;
        final productType = productData['type'];  // Get 'type' field from product

        print("Found product type: $productType");
        final toLowerProductType = productType.toLowerCase();

        // Now use the product's 'type' to find the corresponding item in the warehouse
        QuerySnapshot warehouseSnapshot = await FirebaseFirestore.instance
            .collection('Companies')
            .doc(currentCompanyName)
            .collection('warehouse')
            .where('type', isEqualTo: toLowerProductType)
            .limit(1)
            .get();

        if (warehouseSnapshot.docs.isNotEmpty) {
          DocumentSnapshot warehouseItem = warehouseSnapshot.docs.first;
          double currentStock = warehouseItem['amount'];

          // Decrease the stock by the ordered quantity
          double updatedStock = currentStock - orderQuantity;

          // Update the warehouse with the new stock level
          await FirebaseFirestore.instance
              .collection('Companies')
              .doc(currentCompanyName)
              .collection('warehouse')
              .doc(warehouseItem.id)
              .update({'amount': updatedStock});

          print("Warehouse updated: $productType, Remaining stock: $updatedStock");
        } else {
          print("Product not found in warehouse.");
        }
      } else {
        print("Product not found in products collection.");
      }
    } catch (e) {
      print("Error updating warehouse stock: $e");
    }
  }

  // Method to delete an order from Firestore
  Future<void> _deleteOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Companies')
          .doc(currentCompanyName)
          .collection('orders')
          .doc(orderId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sipariş başarıyla silindi')),
      );
    } catch (e) {
      print("Error deleting order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sipariş silinirken hata oluştu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentCompanyName == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişlerim'),
        actions: [
          Row(
            children: [
              Text(
                'Sipariş Numarasına Göre Filtrele',
                style: const TextStyle(fontSize: 14),
              ),
              IconButton(
                icon: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                tooltip: isAscending ? 'Sort Ascending' : 'Sort Descending',
                onPressed: () {
                  setState(() {
                    isAscending = !isAscending;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Siparişler bulunamadı.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şirket adı: ${data['clientName']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Sipariş Numarası: ${data['orderNumber']}'),
                      Text('Ürün: ${data['product']}'),
                      Text('Total: ${NumberFormat('#,###').format(data['amount'])}',),
                      Text('Total: ${NumberFormat('#,###').format(data['pricePerUnit'])}',),
                      Text('Total: ${NumberFormat('#,###').format(data['total'])}',),

                      Text(
                        'Tarih: ${data['date'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['date'] as Timestamp).toDate().toLocal()) : 'Tarih yok'}',
                      ),
                      const SizedBox(height: 30),
                      Wrap(
                        spacing: 16.0,
                        runSpacing: 10.0,
                        alignment: WrapAlignment.start,
                        children: [
                          // Other switches (paymentStatus, deliveryStatus, etc.)
                          ElevatedButton(
                            onPressed: () => _editOrder(order.id, data),
                            child: const Text('Düzenle'),
                          ),
                          // Add the "Delete" button next to the "Düzenle" button
                          ElevatedButton(
                            onPressed: () => _deleteOrder(order.id),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                      // Display fields for editing when in edit mode
                      if (_editingOrderId == order.id)
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            TextField(
                              controller: _productController,
                              decoration: const InputDecoration(labelText: 'Ürün'),
                            ),
                            TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Kaç Adet'),
                            ),
                            TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Birim Fiyatı'),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _updateOrder,
                              child: const Text('Güncelle'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
