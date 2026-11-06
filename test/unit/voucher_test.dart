import 'package:flutter_test/flutter_test.dart';
import 'package:ayubo_customer_app/utils/money.dart';
import 'package:ayubo_customer_app/widgets/voucher_state_chip.dart';

void main() {
  setUp(() {
    currentAppLocale = 'en';
  });

  group('VoucherStateChip labels', () {
    test('formats English voucher state labels correctly', () {
      expect(voucherStateLabel('available', 'en'), 'Available');
      expect(voucherStateLabel('partially_redeemed', 'en'), 'Partially redeemed');
      expect(voucherStateLabel('used', 'en'), 'Fully redeemed');
      expect(voucherStateLabel('fully_redeemed', 'en'), 'Fully redeemed');
      expect(voucherStateLabel('expired', 'en'), 'Expired');
      expect(voucherStateLabel('cancelled', 'en'), 'Cancelled');
    });

    test('formats German voucher state labels correctly', () {
      expect(voucherStateLabel('available', 'de'), 'Verfügbar');
      expect(voucherStateLabel('partially_redeemed', 'de'), 'Teilweise eingelöst');
      expect(voucherStateLabel('used', 'de'), 'Vollständig eingelöst');
      expect(voucherStateLabel('fully_redeemed', 'de'), 'Vollständig eingelöst');
      expect(voucherStateLabel('expired', 'de'), 'Abgelaufen');
      expect(voucherStateLabel('cancelled', 'de'), 'Storniert');
    });

    test('formats voucher kind labels correctly', () {
      expect(voucherKindLabel('issued', 'en'), 'Issued by staff');
      expect(voucherKindLabel('purchased', 'en'), 'Bought in the shop');
      expect(voucherKindLabel('membership_credit', 'en'), 'Membership credit');
      expect(voucherKindLabel('membership_credit', 'de'), 'Mitgliedschaftsguthaben');
      expect(voucherKindLabel('gift_voucher', 'en'), 'gift voucher');
    });
  });
}
