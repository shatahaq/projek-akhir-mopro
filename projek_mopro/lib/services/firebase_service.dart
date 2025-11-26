import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/product.dart';
import '../models/user_data.dart';
import '../models/order_model.dart';
import '../models/cart_item.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        userData['id'] = userCredential.user!.uid;
        userData['status'] = 'success';
        return userData;
      } else { return {"status": "error", "message": "User data not found"}; }
    } on FirebaseAuthException catch (e) { return {"status": "error", "message": e.message}; } catch (e) { return {"status": "error", "message": e.toString()}; }
  }

  static Future<Map<String, dynamic>> register(String email, String password, String role, String fullname, String nim, File? imageFile) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      String imgUrl = '';
      if (imageFile != null) {
        Reference ref = _storage.ref().child('user_images/${userCredential.user!.uid}.jpg');
        await ref.putFile(imageFile);
        imgUrl = await ref.getDownloadURL();
      }
      await _firestore.collection('users').doc(userCredential.user!.uid).set({'email': email, 'role': role, 'fullname': fullname, 'nim': nim, 'img': imgUrl, 'created_at': FieldValue.serverTimestamp()});
      return {"status": "success"};
    } on FirebaseAuthException catch (e) { return {"status": "error", "message": e.message}; } catch (e) { return {"status": "error", "message": e.toString()}; }
  }

  static Future<List<Product>> getProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('products').get();
      return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
    } catch (e) { return []; }
  }

  static Future<bool> addProduct(String nama, String kategori, String harga, String stok, String deskripsi, File? imageFile, String sellerId, String sellerName) async {
    try {
      String imgUrl = '';
      if (imageFile != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = _storage.ref().child('product_images/$fileName.jpg');
        await ref.putFile(imageFile);
        imgUrl = await ref.getDownloadURL();
      }
      await _firestore.collection('products').add({'nama': nama, 'kategori': kategori, 'harga': int.parse(harga), 'stok': int.parse(stok), 'deskripsi': deskripsi, 'img': imgUrl, 'seller_id': sellerId, 'seller_name': sellerName, 'rating': 0.0, 'reviews': 0, 'created_at': FieldValue.serverTimestamp()});
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> deleteProduct(String id) async {
    try { await _firestore.collection('products').doc(id).delete(); return true; } catch (e) { return false; }
  }

  static Future<String> createOrder(String userId, String buyerName, int total, List<CartItem> items, String address, String paymentMethod, String promoCode) async {
    try {
      // Use transaction to ensure atomic stock reduction
      return await _firestore.runTransaction<String>((transaction) async {
        // Step 1: Validate and prepare stock updates
        Map<String, int> stockUpdates = {};
        
        for (var item in items) {
          DocumentReference productRef = _firestore.collection('products').doc(item.id);
          DocumentSnapshot productSnap = await transaction.get(productRef);
          
          if (!productSnap.exists) {
            throw Exception("Product ${item.nama} not found");
          }
          
          int currentStock = productSnap['stok'] ?? 0;
          
          if (currentStock < item.qty) {
            throw Exception("Insufficient stock for ${item.nama}. Available: $currentStock, Requested: ${item.qty}");
          }
          
          stockUpdates[item.id] = currentStock - item.qty;
        }
        
        // Step 2: Update stock for all products
        for (var entry in stockUpdates.entries) {
          DocumentReference productRef = _firestore.collection('products').doc(entry.key);
          transaction.update(productRef, {'stok': entry.value});
        }
        
        // Step 3: Create order
        List<Map<String, dynamic>> orderItems = items.map((item) => {
          'product_id': item.id, 
          'product_name': item.nama, 
          'quantity': item.qty, 
          'price': item.harga, 
          'img': item.img
        }).toList();
        
        DocumentReference orderRef = _firestore.collection('orders').doc();
        transaction.set(orderRef, {
          'user_id': userId, 
          'buyer_name': buyerName, 
          'total_price': total, 
          'status': 'pending', 
          'shipping_address': address, 
          'payment_method': paymentMethod, 
          'promo_code': promoCode, 
          'items': orderItems, 
          'created_at': FieldValue.serverTimestamp()
        });
        
        return "OK";
      });
    } catch (e) { 
      return e.toString(); 
    }
  }

  static Future<List<OrderModel>> getOrders({String? userId}) async {
    try {
      Query query = _firestore.collection('orders').orderBy('created_at', descending: true);
      if (userId != null) query = query.where('user_id', isEqualTo: userId);
      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Error getting orders: $e");
      return [];
    }
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    try { await _firestore.collection('orders').doc(id).update({'status': status}); } catch (e) {}
  }

  static Future<List<UserData>> getUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => UserData.fromFirestore(doc)).toList();
    } catch (e) { return []; }
  }

  static Future<void> deleteUser(String id) async {
    try { await _firestore.collection('users').doc(id).delete(); } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getUserReview(String productId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data() as Map<String, dynamic>;
        data['id'] = snapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print(e);
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('reviews')
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print(e);
      return [];
    }
  }

  static Future<void> addReview(String productId, String userId, String userName, double rating, String comment) async {
    try {
      // Check if user already has a review
      Map<String, dynamic>? existingReview = await getUserReview(productId, userId);
      
      DocumentSnapshot productDoc = await _firestore.collection('products').doc(productId).get();
      double currentRating = (productDoc['rating'] ?? 0).toDouble();
      int currentReviews = productDoc['reviews'] ?? 0;
      
      if (existingReview != null) {
        // Update existing review
        String reviewId = existingReview['id'];
        double oldRating = (existingReview['rating'] ?? 0).toDouble();
        
        await _firestore
            .collection('products')
            .doc(productId)
            .collection('reviews')
            .doc(reviewId)
            .update({
          'rating': rating,
          'comment': comment,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Recalculate rating (remove old rating, add new rating)
        double newRating = currentReviews > 0
            ? ((currentRating * currentReviews) - oldRating + rating) / currentReviews
            : rating;
        
        await _firestore.collection('products').doc(productId).update({'rating': newRating});
      } else {
        // Add new review
        await _firestore.collection('products').doc(productId).collection('reviews').add({
          'user_id': userId,
          'user_name': userName,
          'rating': rating,
          'comment': comment,
          'created_at': FieldValue.serverTimestamp()
        });
        
        // Calculate new average rating
        double newRating = ((currentRating * currentReviews) + rating) / (currentReviews + 1);
        await _firestore.collection('products').doc(productId).update({
          'rating': newRating,
          'reviews': currentReviews + 1
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }

  static Future<void> deleteReview(String productId, String userId) async {
    try {
      // Get the review to delete
      Map<String, dynamic>? existingReview = await getUserReview(productId, userId);
      
      if (existingReview != null) {
        String reviewId = existingReview['id'];
        double oldRating = (existingReview['rating'] ?? 0).toDouble();
        
        // Delete the review
        await _firestore
            .collection('products')
            .doc(productId)
            .collection('reviews')
            .doc(reviewId)
            .delete();
        
        // Update product rating and review count
        DocumentSnapshot productDoc = await _firestore.collection('products').doc(productId).get();
        double currentRating = (productDoc['rating'] ?? 0).toDouble();
        int currentReviews = productDoc['reviews'] ?? 0;
        
        if (currentReviews > 1) {
          // Recalculate rating without the deleted review
          double newRating = ((currentRating * currentReviews) - oldRating) / (currentReviews - 1);
          await _firestore.collection('products').doc(productId).update({
            'rating': newRating,
            'reviews': currentReviews - 1
          });
        } else {
          // No reviews left, reset to 0
          await _firestore.collection('products').doc(productId).update({
            'rating': 0.0,
            'reviews': 0
          });
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }
  
  static Future<Map<String, dynamic>> updateProfile(String id, String fullname, String nim, File? imageFile) async {
      try {
          String imgUrl = '';
          Map<String, dynamic> updates = {'fullname': fullname, 'nim': nim};
          if (imageFile != null) {
              Reference ref = _storage.ref().child('user_images/$id.jpg');
              await ref.putFile(imageFile);
              imgUrl = await ref.getDownloadURL();
              updates['img'] = imgUrl;
          }
          await _firestore.collection('users').doc(id).update(updates);
          return {'status': 'success', 'imgUrl': imgUrl.isNotEmpty ? imgUrl : null};
      } catch (e) { return {'status': 'error', 'message': e.toString()}; }
  }
}
