import 'package:flutter/material.dart';
import '../../models/user_data.dart';
import '../../models/order_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/snackbar_helper.dart';

class FilteredOrdersPage extends StatefulWidget {
  final UserData user;
  final String filterStatus;
  final String filterTitle;
  
  const FilteredOrdersPage({
    super.key,
    required this.user,
    required this.filterStatus,
    required this.filterTitle,
  });

  @override
  State<FilteredOrdersPage> createState() => _FilteredOrdersPageState();
}

class _FilteredOrdersPageState extends State<FilteredOrdersPage> {
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() async {
    setState(() => _loading = true);
    var allOrders = await FirebaseService.getOrders(userId: widget.user.id);
    
    // Filter orders based on status
    List<OrderModel> filtered = allOrders.where((order) {
      return order.status == widget.filterStatus;
    }).toList();
    
    setState(() {
      _orders = filtered;
      _loading = false;
    });
  }

  void _rate(String pid, String pname) async {
    // Check if user already has a review
    Map<String, dynamic>? existingReview = 
        await FirebaseService.getUserReview(pid, widget.user.id);
    
    final c = TextEditingController(
      text: existingReview?['comment'] ?? '',
    );
    double r = existingReview != null 
        ? (existingReview['rating'] ?? 5.0).toDouble() 
        : 5.0;
    bool isEditing = existingReview != null;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, st) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEditing ? "Edit Ulasan" : "Beri Ulasan",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pname,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                "Rating:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => st(() => r = i + 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < r ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Komentar",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: c,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Tulis ulasan Anda di sini...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              )
            ],
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showConfirmDialog(
                    context,
                    "Hapus Ulasan",
                    "Yakin ingin menghapus ulasan ini?",
                    () async {
                      await FirebaseService.deleteReview(pid, widget.user.id);
                      showSuccessSnackbar(context, "Ulasan berhasil dihapus!");
                    },
                  );
                },
                child: const Text(
                  "Hapus",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Batal",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                await FirebaseService.addReview(
                    pid, widget.user.id, widget.user.fullname, r, c.text);
                Navigator.pop(ctx);
                showSuccessSnackbar(
                  context, 
                  isEditing ? "Ulasan berhasil diperbarui!" : "Terima kasih!",
                );
                _loadOrders(); // Refresh
              },
              child: Text(isEditing ? "Update" : "Kirim"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStepper(String status) {
    int step = 0;
    if (status == 'pending') step = 1;
    if (status == 'packed') step = 2;
    if (status == 'shipped') step = 3;
    if (status == 'completed') step = 4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepItem("pending", step >= 1),
        _line(step >= 2),
        _stepItem("packed", step >= 2),
        _line(step >= 3),
        _stepItem("shipped", step >= 3),
        _line(step >= 4),
        _stepItem("delivered", step >= 4),
      ],
    );
  }

  Widget _stepItem(String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? Colors.orange : Colors.grey[300],
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? Colors.black87 : Colors.grey,
          ),
        )
      ],
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? Colors.orange : Colors.grey[300],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filterTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Tidak ada pesanan",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _orders.length,
                  itemBuilder: (c, i) {
                    final x = _orders[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Order #${x.id.substring(0, 6)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  x.date.length > 16
                                      ? x.date.substring(0, 16)
                                      : x.date,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildStatusStepper(x.status),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 10),
                            ...x.items.map((it) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          it['product_name'],
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      Text(
                                        "${it['quantity']}x",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total: ${formatRupiah(x.total)}",
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (x.status == 'completed')
                                  TextButton(
                                    onPressed: () {
                                      if (x.items.isNotEmpty) {
                                        _rate(x.items[0]['product_id'],
                                            x.items[0]['product_name']);
                                      }
                                    },
                                    child: const Text("Review"),
                                  )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
