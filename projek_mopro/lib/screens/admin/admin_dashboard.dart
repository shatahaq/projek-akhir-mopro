import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_data.dart';
import '../../models/order_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/image_helper.dart';
import '../../widgets/snackbar_helper.dart';
import '../auth/login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _idx = 0;
  final List<Widget> _pages = [const AdminUserList(), const AdminOrderList()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showConfirmDialog(context, "Logout", "Keluar sebagai admin?",
                  () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              });
            },
          )
        ],
      ),
      body: _pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people),
            label: "Users",
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: "Orders",
          )
        ],
      ),
    );
  }
}

class AdminUserList extends StatefulWidget {
  const AdminUserList({super.key});
  @override
  State<AdminUserList> createState() => _AdminUserListState();
}

class _AdminUserListState extends State<AdminUserList> {
  List<UserData> _u = [];
  bool _l = true;

  @override
  void initState() {
    super.initState();
    _ref();
  }

  void _ref() async {
    var d = await FirebaseService.getUsers();
    setState(() {
      _u = d;
      _l = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _l
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _u.length,
            itemBuilder: (c, i) => ListTile(
              leading: CircleAvatar(
                backgroundImage: getDynamicImage(_u[i].img),
              ),
              title: Text(_u[i].fullname),
              subtitle: Text("${_u[i].email} (${_u[i].role})"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  showConfirmDialog(context, "Hapus User",
                      "Hapus ${_u[i].fullname}?", () async {
                    await FirebaseService.deleteUser(_u[i].id);
                    _ref();
                  });
                },
              ),
            ),
          );
  }
}

class AdminOrderList extends StatefulWidget {
  const AdminOrderList({super.key});
  @override
  State<AdminOrderList> createState() => _AdminOrderListState();
}

class _AdminOrderListState extends State<AdminOrderList> {
  List<OrderModel> _o = [];
  bool _l = true;

  @override
  void initState() {
    super.initState();
    _ref();
  }

  void _ref() async {
    var d = await FirebaseService.getOrders();
    setState(() {
      _o = d;
      _l = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _l
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _o.length,
            itemBuilder: (c, i) {
              final x = _o[i];
              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(
                    "Order #${x.id.substring(0, 8)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        x.buyerName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Total: ${formatRupiah(x.total)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    const Divider(),
                    ...x.items.map((it) => ListTile(
                          dense: true,
                          title: Text(it['product_name']),
                          trailing: Text(
                            "${it['quantity']}x",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Status Pesanan:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(x.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(x.status),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: x.status,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                style: TextStyle(
                                  color: _getStatusColor(x.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                dropdownColor: Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('PENDING'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'packed',
                                    child: Text('PACKED'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'shipped',
                                    child: Text('SHIPPED'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('DELIVERED'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('CANCELLED'),
                                  ),
                                ],
                                onChanged: (newStatus) async {
                                  if (newStatus != null) {
                                    await FirebaseService.updateOrderStatus(
                                        x.id, newStatus);
                                    _ref();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'packed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
