import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/user_data.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/image_helper.dart';
import '../../widgets/star_rating.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final Function(Product) onAdd;
  final UserData user;
  const ProductDetailPage({super.key, required this.product, required this.onAdd, required this.user});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  void _loadReviews() async {
    var reviews = await FirebaseService.getProductReviews(widget.product.id);
    setState(() {
      _reviews = reviews;
      _loadingReviews = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: widget.product.id,
                child: Image(
                  image: getDynamicImage(widget.product.img),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.product.nama,
                            style: titleStyle.copyWith(fontSize: 24),
                          ),
                        ),
                        Text(
                          formatRupiah(widget.product.harga),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        buildStarRating(widget.product.rating, size: 20),
                        const SizedBox(width: 5),
                        Text(
                          "${widget.product.rating.toStringAsFixed(1)} (${widget.product.reviews} Reviews)",
                          style: const TextStyle(color: Colors.grey),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, size: 15, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Penjual: ${widget.product.sellerName}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Deskripsi",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.product.deskripsi,
                      style: const TextStyle(color: textLight, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    
                    // Reviews Section
                    const Divider(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Ulasan Produk",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${_reviews.length} ulasan",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    _loadingReviews
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _reviews.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(30),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.rate_review_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Belum ada ulasan",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: _reviews.map((review) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: primaryColor,
                                              child: Text(
                                                review['user_name'][0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    review['user_name'],
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  buildStarRating(
                                                    (review['rating'] ?? 0).toDouble(),
                                                    size: 14,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (review['created_at'] != null)
                                              Text(
                                                DateFormat('dd MMM yyyy').format(
                                                  review['created_at'].toDate(),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (review['comment'] != null && 
                                            review['comment'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            review['comment'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                    
                    const SizedBox(height: 30),
                    if (widget.user.role != 'penjual')
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: widget.product.stok > 0 ? () {
                            widget.onAdd(widget.product);
                            Navigator.pop(context);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.product.stok > 0 ? primaryColor : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            widget.product.stok > 0 ? "TAMBAH KE KERANJANG" : "STOK HABIS",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                  ],
                ),
              )
            ]),
          )
        ],
      ),
    );
  }
}
