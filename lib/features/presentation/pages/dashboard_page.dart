import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For formatting numbers

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? companyId;
  Map<String, double> productSales = {};
  bool isLoading = true;

  String selectedFilter = 'Month'; // Default filter (for monthly earnings)
  Map<String, double> totalEarnings = {}; // To hold the total earnings based on filter

  List<String> filters = [
    'Week', 'Month', 'Last Month', 'Last 3 Months', 'Last 6 Months', 'Last 12 Months'
  ];

  double totalEarningsOfYear = 0;
  double totalEarningsOfMonth = 0;
  Map<String, double> productEarningsOfMonth = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
  try {
    print("Fetching the current logged-in user...");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("No logged-in user.");
    }

    print("Fetching user document...");
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception("User document not found.");
    }

    final companyIdFromDoc = userDoc.data()!['companyId'] as String?;
    print("Fetched companyId: $companyIdFromDoc");

    if (companyIdFromDoc == null) {
      throw Exception("Company ID is null.");
    }

    print("Fetching orders for companyId: $companyIdFromDoc...");
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('Companies')
        .doc(companyIdFromDoc)
        .collection('orders')
        .get();

    print("Fetched ${ordersSnapshot.docs.length} orders.");
    Map<String, double> salesData = {};
    totalEarnings = {};
    totalEarningsOfYear = 0;
    totalEarningsOfMonth = 0;
    productEarningsOfMonth = {};

    for (var doc in ordersSnapshot.docs) {
      final data = doc.data();
      final productName = data['product'] as String?;
      final total = data['total'];  // `total` can be an int or double
      final date = data['date'] as Timestamp?;

      if (productName != null && total != null && date != null) {
        // Ensure total is treated as a double, regardless of its original type
        double earningsFromOrder = total is int ? total.toDouble() : total;

        // Aggregate sales data
        salesData[productName] = (salesData[productName] ?? 0) + earningsFromOrder;

        // Filter orders by date and calculate total earnings
        if (_isWithinSelectedFilter(date.toDate())) {
          totalEarnings['total'] = (totalEarnings['total'] ?? 0) + earningsFromOrder;
          totalEarningsOfMonth += earningsFromOrder;
        }

        // Calculate total earnings of the year
        if (_isWithinYear(date.toDate())) {
          totalEarningsOfYear += earningsFromOrder;
        }

        // Calculate product earnings for this month
        if (_isWithinCurrentMonth(date.toDate())) {
          productEarningsOfMonth[productName] = (productEarningsOfMonth[productName] ?? 0) + earningsFromOrder;
        }
      }
    }

    print("Aggregated product sales data: $salesData");
    setState(() {
      companyId = companyIdFromDoc;
      productSales = salesData;
      isLoading = false;
    });
  } catch (e) {
    print("Error during fetching process: $e");
    setState(() {
      isLoading = false;
    });
  }
}

  // Check if the given date is within the selected filter range
  bool _isWithinSelectedFilter(DateTime date) {
    DateTime now = DateTime.now();
    DateTime filterDate;

    switch (selectedFilter) {
      case 'Week':
        filterDate = now.subtract(Duration(days: 7));
        break;
      case 'Month':
        filterDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Last Month':
        filterDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'Last 3 Months':
        filterDate = now.subtract(Duration(days: 90));
        break;
      case 'Last 6 Months':
        filterDate = now.subtract(Duration(days: 180));
        break;
      case 'Last 12 Months':
        filterDate = now.subtract(Duration(days: 365));
        break;
      default:
        return false;
    }

    return date.isAfter(filterDate);
  }

  bool _isWithinYear(DateTime date) {
    DateTime now = DateTime.now();
    return date.year == now.year;
  }

  bool _isWithinCurrentMonth(DateTime date) {
    DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gösterge Paneli')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : productSales.isEmpty
              ? const Center(child: Text('No sales data available'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Pie chart for product sales distribution
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Ürün satış dağılımı',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 250,
                                        child: PieChart(
                                          PieChartData(
                                            sections: productSales.entries.map((entry) {
                                              final percentage = (entry.value /
                                                      productSales.values
                                                          .reduce((a, b) => a + b)) *
                                                  100;
                                              return PieChartSectionData(
                                                value: entry.value,
                                                title:
                                                    '${percentage.toStringAsFixed(1)}%',
                                                color: Colors.primaries[
                                                    productSales.keys
                                                            .toList()
                                                            .indexOf(entry.key) %
                                                        Colors.primaries.length],
                                                radius: 80,
                                                titleStyle: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              );
                                            }).toList(),
                                            centerSpaceRadius: 40,
                                            sectionsSpace: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Açıklamalar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...productSales.entries.map((entry) {
                                        final color = Colors.primaries[
                                            productSales.keys
                                                    .toList()
                                                    .indexOf(entry.key) %
                                                Colors.primaries.length];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Small Boxes for Earnings (Neatly arranged)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Total Yearly Earnings & Monthly Earnings in a Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildInfoBox('Toplam Yıl Geliri', totalEarningsOfYear),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildInfoBox('Bu Ay Geliri', totalEarningsOfMonth),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Product Earnings for the Month (as a Grid)
                                GridView.builder(
                                  shrinkWrap: true,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: productEarningsOfMonth.length,
                                  itemBuilder: (context, index) {
                                    final product = productEarningsOfMonth.keys.elementAt(index);
                                    final earnings = productEarningsOfMonth[product];
                                    return _buildInfoBox(product, earnings ?? 0);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoBox(String title, double amount) {
    // Format the amount with thousand separators
    final formattedAmount = NumberFormat('#,###', 'en_US').format(amount);

    return Container(
      width: 160, // Fixed width
      height: 120, // Fixed height
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            formattedAmount, // Display the formatted amount
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
