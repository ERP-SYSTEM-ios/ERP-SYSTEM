import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsPage extends StatefulWidget {
  final String companyId; // Company ID passed dynamically
  const ProductsPage({required this.companyId, super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _consumptionController = TextEditingController(); // New controller for raw material consumption per piece

  String? _selectedType;
  String? _selectedUnit; // Variable to store selected unit
  String? _itemId; // Store the ID of the item being edited

  // List of units of measure (kg, gram, ton, etc.)
  final List<String> _unitList = ['kg', 'gram', 'ton', 'liter', 'pieces'];

  // Fetch available types from the warehouse subcollection
  Future<List<String>> _fetchRawMaterialTypes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Companies')
          .doc(widget.companyId)
          .collection('warehouse')
          .get();

      final types = snapshot.docs.map((doc) => doc['type'] as String).toList();
      return types;
    } catch (e) {
      return [];
    }
  }

  Future<void> _addOrUpdateProduct() async {
    if (_selectedType == null ||
        _nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedUnit == null ||
        _consumptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    try {
      final product = {
        'type': _selectedType,
        'name': _nameController.text,
        'price': double.parse(_priceController.text),
        'unit': _selectedUnit,  // Add the selected unit
        'consumptionPerPiece': double.parse(_consumptionController.text), // Raw material consumption per piece
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_itemId == null) {
        // If editing an existing item, update it
        await FirebaseFirestore.instance
            .collection('Companies')
            .doc(widget.companyId)
            .collection('products')
            .add(product);
      } else {
        // If it's a new item, add a new one
        await FirebaseFirestore.instance
            .collection('Companies')
            .doc(widget.companyId)
            .collection('products')
            .doc(_itemId) // Reference the existing document to update
            .update(product);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün kaydedildi')),
      );

      // Clear form fields and reset the state
      _selectedType = null;
      _selectedUnit = null;
      _consumptionController.clear();
      _nameController.clear();
      _priceController.clear();
      setState(() {
        _itemId = null; // Reset item ID for new item
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün kaydedilemedi: $e')),
      );
    }
  }

  void _showAddOrUpdateProductForm({DocumentSnapshot? document}) {
    if (document != null) {
      // If editing an existing item, pre-fill the form with the existing data
      _nameController.text = document['name'];
      _priceController.text = document['price'].toString();
      _selectedType = document['type'];
      _selectedUnit = document['unit'] ?? 'kg'; // Check if 'unit' field exists, otherwise fallback to 'kg'
      _consumptionController.text = document['consumptionPerPiece']?.toString() ?? '0'; // Pre-fill consumption value
      _itemId = document.id; // Store the document ID for updating
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ürün Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<String>>(
                future: _fetchRawMaterialTypes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Henüz hammadde eklenmemiş');
                  }

                  final types = snapshot.data!;

                  return DropdownButton<String>(
                    hint: const Text('Hammadde Türü Seçin'),
                    value: _selectedType,
                    onChanged: (String? newType) {
                      setState(() {
                        _selectedType = newType;
                      });
                    },
                    items: types.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                  );
                },
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ürün Adı'),
              ),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Fiyat'),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: _selectedUnit,
                hint: const Text('Birimi Seçin'),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedUnit = newValue;
                  });
                },
                items: _unitList.map<DropdownMenuItem<String>>((String unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
              ),
              TextField(
                controller: _consumptionController,
                decoration: const InputDecoration(labelText: 'Hammadde Tüketimi (Adet Başına)'),
                keyboardType: TextInputType.number,
              ),
            ],
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
                await _addOrUpdateProduct();
                Navigator.pop(context); // Close the dialog after saving
              },
              child: const Text('Kaydet'),
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
        title: const Text('Ürünler'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Companies')
                    .doc(widget.companyId)
                    .collection('products')
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
                          const Text('Henüz ürün eklenmemiş'),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _showAddOrUpdateProductForm,
                            child: const Text('Ürün Ekle'),
                          ),
                        ],
                      ),
                    );
                  }

                  final products = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text(
                            'Tür: ${product['type']} - Fiyat: ${product['price']} - Birim: ${product['unit']} - Hammadde Tüketimi: ${product['consumptionPerPiece']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddOrUpdateProductForm(document: product),
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
        onPressed: _showAddOrUpdateProductForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
