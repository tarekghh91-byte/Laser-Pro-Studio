import 'package:flutter_test/flutter_test.dart';
import 'package:laser_pro_studio/main.dart' as core;

void main() {
  group('Supplier purchase accounting', () {
    test('partial supplier payments survive JSON round-trip and reduce balance', () {
      final purchase = core.StockPurchase(
        id: 'purchase-1', supplierId: 'supplier-1', supplierName: 'Supplier',
        materialId: 'wood-3mm', materialName: '3mm wood', packageCount: 2,
        packUnits: 10, baseQuantity: 20, packageCost: 15, unitCost: 1.5,
        totalAmount: 30, paymentMethod: 'Whish Money', paidAmount: 10,
        payments: [core.SupplierPaymentEntry(
          id: 'payment-1', amount: 10, method: 'Whish Money',
          paidAt: DateTime.utc(2026, 11, 3), notes: 'First installment')],
        invoiceNumber: 'INV-01', purchaseDate: DateTime.utc(2026, 11, 3));

      expect(purchase.outstanding, 20);
      final restored = core.StockPurchase.fromJson(purchase.toJson());
      expect(restored.paidAmount, 10);
      expect(restored.outstanding, 20);
      expect(restored.payments, hasLength(1));
      expect(restored.payments.single.method, 'Whish Money');
      expect(restored.payments.single.notes, 'First installment');
    });

    test('fully paid supplier invoice has zero outstanding balance', () {
      final purchase = core.StockPurchase(
        id: 'purchase-2', supplierId: 'supplier-1', supplierName: 'Supplier',
        materialId: 'wood-3mm', materialName: '3mm wood', packageCount: 1,
        packUnits: 10, baseQuantity: 10, packageCost: 25, unitCost: 2.5,
        totalAmount: 25, paymentMethod: 'نقداً', paidAmount: 25,
        invoiceNumber: 'INV-02', purchaseDate: DateTime.utc(2026, 11, 3));

      expect(purchase.outstanding, 0);
    });
  });
}
