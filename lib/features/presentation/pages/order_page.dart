import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';


class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  DateTime? _selectedDate;
  double _total = 0.0;
  String? currentCompanyName;
  bool _paymentStatus = false;
  bool _deliveryStatus = false;
  bool _productionStatus = false;
  List<String> productSuggestions = [];
  List<String> customerSuggestions = [];  // List to hold customer suggestions
  bool isFetchingOrderNumber = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUserCompany();
  }

  // Fetch current user company
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
          _fetchLatestOrderNumber();  // Fetch order number after company name is set
        }
      }
    } catch (e) {
      print("Error fetching user company: $e");
    }
  }

  // Fetch latest order number
  Future<void> _fetchLatestOrderNumber() async {
    if (currentCompanyName == null) return;

    try {
      var ordersSnapshot = await FirebaseFirestore.instance
          .collection('Companies')
          .doc(currentCompanyName)
          .collection('orders')
          .orderBy('orderNumber', descending: true)
          .limit(1)
          .get();

      if (ordersSnapshot.docs.isNotEmpty) {
        String orderNumberString = ordersSnapshot.docs.first['orderNumber'].toString();
        int latestOrderNumber = int.parse(orderNumberString);
        setState(() {
          _orderNumberController.text = (latestOrderNumber + 1).toString();
        });
      } else {
        setState(() {
          _orderNumberController.text = '1';
        });
      }
    } catch (e) {
      print("Error fetching latest order number: $e");
      setState(() {
        _orderNumberController.text = '1';
      });
    } finally {
      setState(() {
        isFetchingOrderNumber = false;
      });
    }
  }
// Fetch customer suggestions

// Fetch customer suggestions
void _fetchCustomerSuggestions(String query) async {
  if (query.isEmpty || currentCompanyName == null) {
    setState(() {
      customerSuggestions = [];
    });
    return;
  }

  try {
    var customerSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('customers')
        .orderBy('companyName')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();

    setState(() {
      customerSuggestions = customerSnapshot.docs
          .map((doc) => doc['companyName'].toString())
          .toList();
    });
    print("Query: $query\uf8ff");
    print("Customer suggestions: $customerSuggestions");
    print("Current comp : $currentCompanyName");
    print("Current customerSnapshot.docs : ${customerSnapshot.docs}");
  } catch (e) {
    print("Error fetching company name suggestions: $e");
  }
}

// Fetch product suggestions
void _fetchProductSuggestions(String query) async {
  if (query.isEmpty || currentCompanyName == null) {
    setState(() {
      productSuggestions = [];
    });
    return;
  }

  try {
    var productSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('products')
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();

    setState(() {
      productSuggestions = productSnapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();
    });
  } catch (e) {
    print("Error fetching product suggestions: $e");
  }
}

// Fetch product price
Future<void> _fetchProductPrice() async {
  if (_productController.text.isEmpty || currentCompanyName == null) return;

  try {
    var productSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('products')
        .where('name', isEqualTo: _productController.text)
        .limit(1)
        .get();

    if (productSnapshot.docs.isNotEmpty) {
      setState(() {
        _priceController.text = productSnapshot.docs.first['price'].toString();
      });
    } else {
      setState(() {
        _priceController.clear();
      });
    }
  } catch (e) {
    print("Error fetching product price: $e");
  }
}

  // Calculate the total price
  void _calculateTotal() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _total = quantity * price;
    });
  }

  // Date picker
  Future<void> _pickDate() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
  );
  if (picked != null) {
    final now = DateTime.now();
    setState(() {
      // Combine picked date with the current time
      _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
    });
  }
}

  // Save the order
    // Save the order and update warehouse stock
 // Save the order and update warehouse stock
Future<void> _saveOrder() async {
  if (_orderNumberController.text.isEmpty ||
      _clientNameController.text.isEmpty ||  
      _productController.text.isEmpty ||
      _quantityController.text.isEmpty ||
      _priceController.text.isEmpty ||
      _selectedDate == null ||
      currentCompanyName == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Lütfen tüm alanları doldurun, bir tarih seçin ve oturum açtığınızdan emin olun')),
    );
    return;
  }

  try {
    // Fetch the product details to get raw material, type, and consumption per unit
    var productSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('products')
        .where('name', isEqualTo: _productController.text)
        .limit(1)
        .get();

    if (productSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün bulunamadı')),
      );
      return;
    }

    var product = productSnapshot.docs.first;
    String productName = product['name'];
    String productType = product['type'];  // Fetching product type
    double consumptionPerUnit = product['consumptionPerPiece'] ?? 0.0;  // Consumption per unit
    int orderedQuantity = int.tryParse(_quantityController.text) ?? 0;
    
    // Calculate the total raw material consumption (in the same unit)
    double totalConsumption = consumptionPerUnit * orderedQuantity;

    // Get the raw material name from the product (e.g., "seker" for sugar)
    String rawMaterialName = product['type']; // raw material name associated with the product

    // Fetch the warehouse stock for the raw material
    var warehouseSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('warehouse')
        .where('type', isEqualTo: rawMaterialName)
        .limit(1)
        .get();
    if (warehouseSnapshot.docs.isEmpty) {
        print(rawMaterialName);
        print(warehouseSnapshot);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hammadde bulunamadı')),
      );
      return;
    }

    var rawMaterial = warehouseSnapshot.docs.first;
    double availableStock = rawMaterial['amount'];  // Available stock in warehouse

    // Check if there is enough raw material in stock
    if (availableStock < totalConsumption) {
      print(rawMaterial);
      print(availableStock);
      print(totalConsumption);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeterli hammadde yok')),
      );
      return;  // Exit if not enough raw material
    }

    // Update the warehouse stock by deducting the used raw material
    double updatedStock = availableStock - totalConsumption;
    await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('warehouse')
        .doc(rawMaterial.id)  // Update the specific raw material document
        .update({'amount': updatedStock});

    // Proceed to save the order after updating the stock
    final order = {
      'orderNumber': int.parse(_orderNumberController.text),
      'clientName': _clientNameController.text,
      'receivingCompany': currentCompanyName,
      'product': productName,
      'productType': productType,  // Include product type
      'amount': orderedQuantity,
      'pricePerUnit': double.parse(_priceController.text),
      'total': _total,
      'date': Timestamp.fromDate(_selectedDate!),
      'paymentStatus': _paymentStatus,  
      'deliveryStatus': _deliveryStatus, 
      'productionStatus': _productionStatus, 
    };

    await FirebaseFirestore.instance
        .collection('Companies')
        .doc(currentCompanyName)
        .collection('orders')
        .add(order);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sipariş eklendi')),
    );

    // Clear fields after saving the order
    _orderNumberController.clear();
    _clientNameController.clear();
    _productController.clear();
    _quantityController.clear();
    _priceController.clear();
    setState(() {
      _total = 0.0;
      _selectedDate = null;
      _paymentStatus = false;  
      _deliveryStatus = false; 
      _productionStatus = false; 
    });

    // Fetch the next order number after saving
    _fetchLatestOrderNumber();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sipariş kaydedilemedi: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Ekle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Order Number
            TextField(
              controller: _orderNumberController,
              decoration: const InputDecoration(labelText: 'Siparis Numara'),
              enabled: !isFetchingOrderNumber,
            ),
            // Client Name
            TextField(
              controller: _clientNameController,
              decoration: const InputDecoration(labelText: 'Müşteri Adı'),
              onChanged: _fetchCustomerSuggestions,  // Fetch customer suggestions
            ),
            // Customer Suggestions
            if (customerSuggestions.isNotEmpty)
              SizedBox(
                height: 100, // Limit the height
                child: ListView.builder(
                  itemCount: customerSuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(customerSuggestions[index]),
                      onTap: () {
                        _clientNameController.text = customerSuggestions[index];
                        setState(() {
                          customerSuggestions = []; // Clear suggestions after selection
                        });
                      },
                    );
                  },
                ),
              ),
            // Product
            TextField(
              controller: _productController,
              decoration: const InputDecoration(labelText: 'Ürün'),
              onChanged: _fetchProductSuggestions,
            ),
            // Product Suggestions
            if (productSuggestions.isNotEmpty)
              SizedBox(
                height: 100, // Limit the height for suggestions
                child: ListView.builder(
                  itemCount: productSuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(productSuggestions[index]),
                      onTap: () {
                        _productController.text = productSuggestions[index];
                        _fetchProductPrice(); // Fetch price when product selected
                        setState(() {
                          productSuggestions = []; // Clear product suggestions
                        });
                      },
                    );
                  },
                ),
              ),
            // Quantity
            TextField(
  controller: _quantityController,
  decoration: const InputDecoration(labelText: 'Kaç Adet'),
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly, // Restrict input to digits
  ],
  onChanged: (_) => _calculateTotal(),
),
            // Price
            TextField(
  controller: _priceController,
  decoration: const InputDecoration(labelText: 'Birim Fiyatı'),
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')), // Allow numbers with optional decimal
  ],
  onChanged: (_) => _calculateTotal(),
),
            const SizedBox(height: 10),
            // Date Picker
            Row(
              children: [
                Text(
                  _selectedDate == null
                      ? 'Tarih seçilmemiş'
                      : 'Date: ${_selectedDate!.toLocal()}'.split(' ')[0],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: const Text('Tarih Seç'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Total
            Text('Total: ${NumberFormat('#,###').format(_total)}',),
            const SizedBox(height: 10),
            // Display the company name from the current user
            if (currentCompanyName != null)
              Text(
                'Firma Adı: $currentCompanyName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),
            // Payment Status Switch
            Row(
              children: [
                const Text('Odeme durumu: '),
                Switch(
                  value: _paymentStatus,
                  onChanged: (value) {
                    setState(() {
                      _paymentStatus = value;
                    });
                  },
                ),
              ],
            ),
            // Delivery Status Switch
            Row(
              children: [
                const Text('Teslimat durumu: '),
                Switch(
                  value: _deliveryStatus,
                  onChanged: (value) {
                    setState(() {
                      _deliveryStatus = value;
                    });
                  },
                ),
              ],
            ),
            // Production Status Switch
            Row(
              children: [
                const Text('Üretim durumu: '),
                Switch(
                  value: _productionStatus,
                  onChanged: (value) {
                    setState(() {
                      _productionStatus = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Add Order Button
            ElevatedButton(
              onPressed: _saveOrder,
              child: const Text('Ekle'),
            ),
          ],
        ), 
      ),
    );
  }
}
