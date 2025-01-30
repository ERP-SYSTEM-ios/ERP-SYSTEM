import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WarehousePage extends StatefulWidget {
  final String companyId; // Company ID passed dynamically
  const WarehousePage({required this.companyId, super.key});

  @override
  _WarehousePageState createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(); // New controller for unit of measure

  // List of units of measure (kg, gram, ton, etc.)
  final List<String> _unitList = ['kg', 'gram', 'ton', 'liter', 'pieces'];

  String? _selectedUnit; // Variable to store the selected unit of measure
  String? _itemId; // Store the ID of the item being edited

  Future<void> _addOrUpdateWarehouse() async {
    if (_typeController.text.isEmpty || _amountController.text.isEmpty || _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    try {
      final warehouseItem = {
        'type': _typeController.text.toLowerCase(),
        'amount': double.parse(_amountController.text),
        'unit': _selectedUnit,  // Store the selected unit
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_itemId == null) {
        // If editing an existing item, update it
        await FirebaseFirestore.instance
            .collection('Companies')
            .doc(widget.companyId)
            .collection('warehouse')
            .add(warehouseItem);
      } else {
        // If it's a new item, add a new one
        await FirebaseFirestore.instance
            .collection('Companies')
            .doc(widget.companyId)
            .collection('warehouse')
            .doc(_itemId) // Reference the existing document to update
            .update(warehouseItem);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok kaydedildi')),
      );

      // Clear form fields and reset the state
      _typeController.clear();
      _amountController.clear();
      _unitController.clear();
      setState(() {
        _selectedUnit = null; // Reset unit selection
        _itemId = null; // Reset item ID for new item
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok kaydedilemedi: $e')),
      );
    }
  }

  void _showAddOrUpdateWarehouseForm({DocumentSnapshot? document}) {
    if (document != null) {
      // If editing an existing item, pre-fill the form with the existing data
      _typeController.text = document['type'];
      _amountController.text = document['amount'].toString();
      _selectedUnit = document['unit'];
      _itemId = document.id; // Store the document ID for updating
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hammadde Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Tür'),
              ),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Miktar'),
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
                await _addOrUpdateWarehouse();
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
    // Ensure companyId is valid before querying Firestore
    if (widget.companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Depo')),
        body: const Center(child: Text('Company ID is invalid.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Depo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Companies')
              .doc(widget.companyId)
              .collection('warehouse')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => _showAddOrUpdateWarehouseForm(),
                  child: const Text('Hammadde Ekle'),
                ),
              );
            }

            final warehouseItems = snapshot.data!.docs;

            return ListView.builder(
              itemCount: warehouseItems.length,
              itemBuilder: (context, index) {
                final item = warehouseItems[index];
                return ListTile(
                  title: Text(item['type']),
                  subtitle: Text(
                      'Miktar: ${item['amount']} ${item['unit']}'),  // Display unit of measure
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showAddOrUpdateWarehouseForm(document: item),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrUpdateWarehouseForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
