import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

/// Represents a product item in the catalog
class Item extends Equatable {
  /// Unique product identifier
  final String id;

  /// Product name
  final String name;

  /// Product price
  final double price;

  const Item({
    required this.id,
    required this.name,
    required this.price,
  });

  /// Creates an Item from JSON
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }

  /// Converts Item to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  @override
  List<Object> get props => [id, name, price];

  @override
  String toString() => 'Item(id: $id, name: $name, price: $price)';
}

// ## lib/src/catalog/catalog_bloc.dart

// import 'dart:convert';
// import 'package:bloc/bloc.dart';
// import 'package:equatable/equatable.dart';
// import 'package:flutter/services.dart';
// import 'item.dart';

// Events
abstract class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object> get props => [];
}

/// Event to load the product catalog from assets
class LoadCatalog extends CatalogEvent {
  const LoadCatalog();
}

// States
abstract class CatalogState extends Equatable {
  const CatalogState();

  @override
  List<Object> get props => [];
}

/// Initial state before catalog is loaded
class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

/// State while catalog is being loaded
class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

/// State when catalog is successfully loaded
class CatalogLoaded extends CatalogState {
  /// List of items in the catalog (read-only)
  final List<Item> items;

  const CatalogLoaded(this.items);

  @override
  List<Object> get props => [items];
}

/// State when catalog loading fails
class CatalogError extends CatalogState {
  /// Error message
  final String message;

  const CatalogError(this.message);

  @override
  List<Object> get props => [message];
}

/// Read-only BLoC for managing product catalog
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc() : super(const CatalogInitial()) {
    on<LoadCatalog>(_onLoadCatalog);
  }

  Future<void> _onLoadCatalog(
    LoadCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogLoading());

    try {
      // Load from assets/catalog.json
      final jsonString = await rootBundle.loadString('assets/catalog.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      final items = jsonList
          .map((json) => Item.fromJson(json as Map<String, dynamic>))
          .toList();

      emit(CatalogLoaded(items));
    } catch (e) {
      emit(CatalogError('Failed to load catalog: ${e.toString()}'));
    }
  }
}

// ## lib/src/cart/models.dart

// import 'package:equatable/equatable.dart';
// import '../catalog/item.dart';

/// Represents a line item in the shopping cart
class CartLine extends Equatable {
  /// The product for this line
  final Item item;

  /// Quantity of the product
  final int quantity;

  /// Discount percentage (0.0 to 1.0)
  final double discountPercent;

  const CartLine({
    required this.item,
    required this.quantity,
    this.discountPercent = 0.0,
  });

  /// Creates a copy with updated values
  CartLine copyWith({
    Item? item,
    int? quantity,
    double? discountPercent,
  }) {
    return CartLine(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  /// Calculates line net total: price × qty × (1 – discount%)
  double get lineNet {
    return item.price * quantity * (1.0 - discountPercent);
  }

  /// Calculates discount amount for this line
  double get discountAmount {
    return item.price * quantity * discountPercent;
  }

  @override
  List<Object> get props => [item, quantity, discountPercent];

  @override
  String toString() =>
      'CartLine(item: ${item.name}, qty: $quantity, discount: ${(discountPercent * 100).toStringAsFixed(1)}%)';
}

/// Represents the calculated totals for a cart
class CartTotals extends Equatable {
  /// Subtotal before VAT (Σ lineNet)
  final double subtotal;

  /// VAT amount (subtotal × 0.15)
  final double vat;

  /// Total discount amount
  final double discount;

  /// Grand total including VAT (subtotal + vat)
  final double grandTotal;

  const CartTotals({
    required this.subtotal,
    required this.vat,
    required this.discount,
    required this.grandTotal,
  });

  /// Creates empty totals
  const CartTotals.empty()
      : subtotal = 0.0,
        vat = 0.0,
        discount = 0.0,
        grandTotal = 0.0;

  @override
  List<Object> get props => [subtotal, vat, discount, grandTotal];

  @override
  String toString() =>
      'CartTotals(subtotal: $subtotal, vat: $vat, discount: $discount, grandTotal: $grandTotal)';
}

/// Immutable state representing the current cart
class CartState extends Equatable {
  /// List of cart lines
  final List<CartLine> lines;

  /// Calculated totals
  final CartTotals totals;

  const CartState({
    required this.lines,
    required this.totals,
  });

  /// Creates an empty cart state
  const CartState.empty()
      : lines = const [],
        totals = const CartTotals.empty();

  /// Creates a copy with updated values
  CartState copyWith({
    List<CartLine>? lines,
    CartTotals? totals,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      totals: totals ?? this.totals,
    );
  }

  /// Checks if cart is empty
  bool get isEmpty => lines.isEmpty;

  /// Gets total number of items in cart
  int get totalItems => lines.fold(0, (sum, line) => sum + line.quantity);

  @override
  List<Object> get props => [lines, totals];

  @override
  String toString() =>
      'CartState(lines: ${lines.length}, totalItems: $totalItems, grandTotal: ${totals.grandTotal})';
}

// ## lib/src/cart/cart_bloc.dart

// import 'package:bloc/bloc.dart';
// import 'package:equatable/equatable.dart';
// import '../catalog/item.dart';
// import 'models.dart';

// Events
abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object> get props => [];
}

/// Event to add an item to the cart
class AddItem extends CartEvent {
  final Item item;
  final int quantity;

  const AddItem(this.item, {this.quantity = 1});

  @override
  List<Object> get props => [item, quantity];
}

/// Event to remove an item from the cart completely
class RemoveItem extends CartEvent {
  final String itemId;

  const RemoveItem(this.itemId);

  @override
  List<Object> get props => [itemId];
}

/// Event to change quantity of an item
class ChangeQty extends CartEvent {
  final String itemId;
  final int quantity;

  const ChangeQty(this.itemId, this.quantity);

  @override
  List<Object> get props => [itemId, quantity];
}

/// Event to change discount for an item
class ChangeDiscount extends CartEvent {
  final String itemId;
  final double discountPercent;

  const ChangeDiscount(this.itemId, this.discountPercent);

  @override
  List<Object> get props => [itemId, discountPercent];
}

/// Event to clear the entire cart
class ClearCart extends CartEvent {
  const ClearCart();
}

/// Cart BLoC that manages shopping cart state and emits running totals
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState.empty()) {
    on<AddItem>(_onAddItem);
    on<RemoveItem>(_onRemoveItem);
    on<ChangeQty>(_onChangeQty);
    on<ChangeDiscount>(_onChangeDiscount);
    on<ClearCart>(_onClearCart);
  }

  void _onAddItem(AddItem event, Emitter<CartState> emit) {
    final existingLineIndex = state.lines.indexWhere(
      (line) => line.item.id == event.item.id,
    );

    List<CartLine> newLines;
    if (existingLineIndex >= 0) {
      // Update existing line quantity
      final existingLine = state.lines[existingLineIndex];
      final updatedLine = existingLine.copyWith(
        quantity: existingLine.quantity + event.quantity,
      );
      newLines = List.from(state.lines);
      newLines[existingLineIndex] = updatedLine;
    } else {
      // Add new line
      newLines = [
        ...state.lines,
        CartLine(item: event.item, quantity: event.quantity),
      ];
    }

    final newTotals = _calculateTotals(newLines);
    emit(CartState(lines: newLines, totals: newTotals));
  }

  void _onRemoveItem(RemoveItem event, Emitter<CartState> emit) {
    final newLines =
        state.lines.where((line) => line.item.id != event.itemId).toList();

    final newTotals = _calculateTotals(newLines);
    emit(CartState(lines: newLines, totals: newTotals));
  }

  void _onChangeQty(ChangeQty event, Emitter<CartState> emit) {
    if (event.quantity <= 0) {
      // Remove item if quantity is 0 or negative
      add(RemoveItem(event.itemId));
      return;
    }

    final lineIndex = state.lines.indexWhere(
      (line) => line.item.id == event.itemId,
    );

    if (lineIndex < 0) return; // Item not found

    final newLines = List<CartLine>.from(state.lines);
    newLines[lineIndex] =
        newLines[lineIndex].copyWith(quantity: event.quantity);

    final newTotals = _calculateTotals(newLines);
    emit(CartState(lines: newLines, totals: newTotals));
  }

  void _onChangeDiscount(ChangeDiscount event, Emitter<CartState> emit) {
    final lineIndex = state.lines.indexWhere(
      (line) => line.item.id == event.itemId,
    );

    if (lineIndex < 0) return; // Item not found

    // Clamp discount between 0 and 1 (0% to 100%)
    final clampedDiscount = event.discountPercent.clamp(0.0, 1.0);

    final newLines = List<CartLine>.from(state.lines);
    newLines[lineIndex] = newLines[lineIndex].copyWith(
      discountPercent: clampedDiscount,
    );

    final newTotals = _calculateTotals(newLines);
    emit(CartState(lines: newLines, totals: newTotals));
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) {
    emit(const CartState.empty());
  }

  /// Calculates totals based on business rules:
  /// - VAT = 15%
  /// - lineNet = price × qty × (1 – discount%)
  /// - subtotal = Σ lineNet
  /// - vat = subtotal × 0.15
  /// - grandTotal = subtotal + vat
  CartTotals _calculateTotals(List<CartLine> lines) {
    double subtotal = 0.0;
    double totalDiscount = 0.0;

    for (CartLine line in lines) {
      subtotal += line.lineNet;
      totalDiscount += line.discountAmount;
    }

    // VAT = 15% of subtotal
    final vat = subtotal * 0.15;
    final grandTotal = subtotal + vat;

    return CartTotals(
      subtotal: subtotal,
      vat: vat,
      discount: totalDiscount,
      grandTotal: grandTotal,
    );
  }
}

// ## lib/src/cart/receipt.dart

// import 'package:equatable/equatable.dart';
// import 'models.dart';

/// Header information for a receipt
class ReceiptHeader extends Equatable {
  /// Receipt timestamp
  final DateTime timestamp;

  /// Receipt number/ID
  final String receiptNumber;

  /// Store/location identifier
  final String? storeId;

  const ReceiptHeader({
    required this.timestamp,
    required this.receiptNumber,
    this.storeId,
  });

  @override
  List<Object?> get props => [timestamp, receiptNumber, storeId];

  @override
  String toString() =>
      'ReceiptHeader(receiptNumber: $receiptNumber, timestamp: $timestamp)';
}

/// Complete receipt model for downstream rendering/printing
class Receipt extends Equatable {
  /// Receipt header information
  final ReceiptHeader header;

  /// List of cart lines at time of checkout
  final List<CartLine> lines;

  /// Calculated totals at time of checkout
  final CartTotals totals;

  const Receipt({
    required this.header,
    required this.lines,
    required this.totals,
  });

  @override
  List<Object> get props => [header, lines, totals];

  @override
  String toString() =>
      'Receipt(${header.receiptNumber}, ${lines.length} lines, total: ${totals.grandTotal})';
}

/// Pure function to build receipt from cart state
/// Receipt buildReceipt(CartState, DateTime) that copies current cart into DTO
Receipt buildReceipt(CartState cartState, DateTime timestamp,
    [String? storeId]) {
  // Generate receipt number based on timestamp
  final receiptNumber = 'R${timestamp.millisecondsSinceEpoch}';

  final header = ReceiptHeader(
    timestamp: timestamp,
    receiptNumber: receiptNumber,
    storeId: storeId,
  );

  return Receipt(
    header: header,
    lines: List.unmodifiable(cartState.lines), // Defensive copy - immutable
    totals: cartState.totals,
  );
}

// ## lib/src/util/money_extension.dart

/// Extension to format numbers as money
extension MoneyExtension on num {
  /// Formats number as money string with 2 decimal places
  String get asMoney {
    return toStringAsFixed(2);
  }
}


// ## test/catalog_bloc_test.dart
// ```dart

// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();

//   group('CatalogBloc', () {
//     late CatalogBloc catalogBloc;

//     setUp(() {
//       catalogBloc = CatalogBloc();
//     });

//     tearDown(() {
//       catalogBloc.close();
//     });

//     test('initial state is CatalogInitial', () {
//       expect(catalogBloc.state, const CatalogInitial());
//     });

//     group('LoadCatalog', () {
//       blocTest<CatalogBloc, CatalogState>(
//         'emits [CatalogLoading, CatalogLoaded] when catalog loads successfully',
//         build: () => catalogBloc,
//         act: (bloc) => bloc.add(const LoadCatalog()),
//         expect: () => [
//           const CatalogLoading(),
//           isA<CatalogLoaded>().having(
//             (state) => state.items.length,
//             'items length',
//             20, // Should have 20 items from catalog.json
//           ),
//         ],
//       );

//       blocTest<CatalogBloc, CatalogState>(
//         'loads correct items from catalog.json',
//         build: () => catalogBloc,
//         act: (bloc) => bloc.add(const LoadCatalog()),
//         wait: const Duration(milliseconds: 100),
//         verify: (bloc) {
//           final state = bloc.state as CatalogLoaded;
//           expect(state.items.length, 20);
          
//           // Verify first few items
//           expect(state.items[0].id, 'p01');
//           expect(state.items[0].name, 'Coffee');
//           expect(state.items[0].price, 2.50);
          
//           expect(state.items[1].id, 'p02');
//           expect(state.items[1].name, 'Bagel');
//           expect(state.items[1].price, 3.20);
//         },
//       );

//       blocTest<CatalogBloc, CatalogState>(
//         'emits [CatalogLoading, CatalogError] when loading fails',
//         build: () {
//           // Override the asset bundle to simulate failure
//           TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
//               .setMockMethodCallHandler(
//             const MethodChannel('flutter/assets'),
//             (methodCall) async {
//               if (methodCall.method == 'loadString') {
//                 throw PlatformException(code: 'ERROR', message: 'Asset not found');
//               }
//               return null;
//             },
//           );
//           return catalogBloc;
//         },
//         act: (bloc) => bloc.add(const LoadCatalog()),
//         expect: () => [
//           const CatalogLoading(),
//           isA<CatalogError>(),
//         ],
//       );
//     });
//   });
// }


// ## test/cart_bloc_test.dart
// import 'package:bloc_test/bloc_test.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:checkout_engine/src/catalog/item.dart';
// import 'package:checkout_engine/src/cart/cart_bloc.dart';
// import 'package:checkout_engine/src/cart/models.dart';

// void main() {
//   group('CartBloc', () {
//     late CartBloc cartBloc;
//     late Item coffee;
//     late Item bagel;

//     setUp(() {
//       cartBloc = CartBloc();
      
//       coffee = const Item(
//         id: 'p01',
//         name: 'Coffee',
//         price: 2.50,
//       );
      
//       bagel = const Item(
//         id: 'p02',
//         name: 'Bagel',
//         price: 3.20,
//       );
//     });

//     tearDown(() {
//       cartBloc.close();
//     });

//     test('initial state is empty cart', () {
//       expect(cartBloc.state, const CartState.empty());
//       expect(cartBloc.state.isEmpty, true);
//       expect(cartBloc.state.totalItems, 0);
//       expect(cartBloc.state.totals.grandTotal, 0.0);
//     });

//     group('Required Test Cases', () {
//       blocTest<CartBloc, CartState>(
//         'Test 1: Two different items → correct totals',
//         build: () => cartBloc,
//         act: (bloc) {
//           bloc.add(AddItem(coffee, quantity: 2)); // 2 × 2.50 = 5.00
//           bloc.add(AddItem(bagel, quantity: 1));  // 1 × 3.20 = 3.20
//         },
//         expect: () => [
//           // After adding coffee
//           CartState(
//             lines: [
//               CartLine(item: coffee, quantity: 2),
//             ],
//             totals: const CartTotals(
//               subtotal: 5.00,      // 2.50 × 2
//               vat: 0.75,           // 5.00 × 0.15
//               discount: 0.0,
//               grandTotal: 5.75,    // 5.00 + 0.75
//             ),
//           ),
//           // After adding bagel
//           CartState(
//             lines: [
//               CartLine(item: coffee, quantity: 2),
//               CartLine(item: bagel, quantity: 1),
//             ],
//             totals: const CartTotals(
//               subtotal: 8.20,      // 5.00 + 3.20
//               vat: 1.23,           // 8.20 × 0.15
//               discount: 0.0,
//               grandTotal: 9.43,    // 8.20 + 1.23
//             ),
//           ),
//         ],
//       );

//       blocTest<CartBloc, CartState>(
//         'Test 2: Qty + discount changes update totals',
//         build: () => cartBloc,
//         seed: () => CartState(
//           lines: [CartLine(item: coffee, quantity: 2)],
//           totals: const CartTotals(
//             subtotal: 5.00,
//             vat: 0.75,
//             discount: 0.0,
//             grandTotal: 5.75,
//           ),
//         ),
//         act: (bloc) {
//           bloc.add(ChangeQty('p01', 3));           // Change qty to 3
//           bloc.add(ChangeDiscount('p01', 0.1));    // Apply 10% discount
//         },
//         expect: () => [
//           // After quantity change: 2.50 × 3 = 7.50
//           CartState(
//             lines: [
//               CartLine(item: coffee, quantity: 3),
//             ],
//             totals: const CartTotals(
//               subtotal: 7.50,      // 2.50 × 3
//               vat: 1.125,          // 7.50 × 0.15 (rounded to 1.13)
//               discount: 0.0,
//               grandTotal: 8.625,   // 7.50 + 1.125 (rounded to 8.63)
//             ),
//           ),
//           // After discount: lineNet = 2.50 × 3 × (1 - 0.1) = 6.75
//           CartState(
//             lines: [
//               CartLine(item: coffee, quantity: 3, discountPercent: 0.1),
//             ],
//             totals: const CartTotals(
//               subtotal: 6.75,      // 2.50 × 3 × 0.9
//               vat: 1.0125,         // 6.75 × 0.15
//               discount: 0.75,      // 2.50 × 3 × 0.1
//               grandTotal: 7.7625,  // 6.75 + 1.0125
//             ),
//           ),
//         ],
//       );

//       blocTest<CartBloc, CartState>(
//         'Test 3: Clearing cart resets state',
//         build: () => cartBloc,
//         seed: () => CartState(
//           lines: [
//             CartLine(item: coffee, quantity: 2),
//             CartLine(item: bagel, quantity: 1),
//           ],
//           totals: const CartTotals(
//             subtotal: 8.20,
//             vat: 1.23,
//             discount: 0.0,
//             grandTotal: 9.43,
//           ),
//         ),
//         act: (bloc) => bloc.add(const ClearCart()),
//         expect: () => [
//           const CartState.empty(),
//         ],
//         verify: (bloc) {
//           expect(bloc.state.isEmpty, true);
//           expect(bloc.state.totalItems, 0);
//           expect(bloc.state.totals.subtotal, 0.0);
//           expect(bloc.state.totals.vat, 0.0);
//           expect(bloc.state.totals.discount, 0.0);
//           expect(bloc.state.totals.grandTotal, 0.0);
//         },
//       );
//     });

//     group('Additional Edge Cases', () {
//       blocTest<CartBloc, CartState>(
//         'adding same item multiple times updates quantity',
//         build: () => cartBloc,
//         act: (bloc) {
//           bloc.add(AddItem(coffee, quantity: 1));
//           bloc.add(AddItem(coffee, quantity: 2)); // Should become qty 3
//         },
//         expect: () => [
//           // First add
//           CartState(
//             lines: [CartLine(item: coffee, quantity: 1)],
//             totals: const CartTotals(
//               subtotal: 2.50,
//               vat: 0.375,
//               discount: 0.0,
//               grandTotal: 2.875,
//             ),
//           ),
//           // Second add - quantity updated to 3
//           CartState(
//             lines: [CartLine(item: coffee, quantity: 3)],
//             totals: const CartTotals(
//               subtotal: 7.50,
//               vat: 1.125,
//               discount: 0.0,
//               grandTotal: 8.625,
//             ),
//           ),
//         ],
//       );

//       blocTest<CartBloc, CartState>(
//         'changing quantity to 0 removes item',
//         build: () => cartBloc,
//         seed: () => CartState(
//           lines: [CartLine(item: coffee, quantity: 2)],
//           totals: const CartTotals(
//             subtotal: 5.00,
//             vat: 0.75,
//             discount: 0.0,
//             grandTotal: 5.75,
//           ),
//         ),
//         act: (bloc) => bloc.add(ChangeQty('p01', 0)),
//         expect: () => [
//           const CartState.empty(),
//         ],
//       );

//       blocTest<CartBloc, CartState>(
//         'discount is clamped between 0 and 1',
//         build: () => cartBloc,
//         seed: () => CartState(
//           lines: [CartLine(item: coffee, quantity: 1)],
//           totals: const CartTotals(
//             subtotal: 2.50,
//             vat: 0.375,
//             discount: 0.0,
//             grandTotal: 2.875,
//           ),
//         ),
//         act: (bloc) => bloc.add(ChangeDiscount('p01', 1.5)), // 150% should clamp to 100%
//         expect: () => [
//           CartState(
//             lines: [CartLine(item: coffee, quantity: 1, discountPercent: 1.0)],
//             totals: const CartTotals(
//               subtotal: 0.0,       // 2.50 × 1 × (1 - 1.0) = 0
//               vat: 0.0,            // 0 × 0.15 = 0
//               discount: 2.50,      // 2.50 × 1 × 1.0 = 2.50
//               grandTotal: 0.0,     // 0 + 0 = 0
//             ),
//           ),
//         ],
//       );
//     });
//   });
// }
// ```

// ## test/receipt_test.dart
// ```dart
// import 'package:flutter_test/flutter_test.dart';
// import 'package:checkout_engine/src/catalog/item.dart';
// import 'package:checkout_engine/src/cart/models.dart';
// import 'package:checkout_engine/src/cart/receipt.dart';

// void main() {
//   group('Receipt Builder', () {
//     late Item coffee;
//     late Item bagel;
//     late CartState cartState;
//     late