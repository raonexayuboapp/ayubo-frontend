import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ayubo Organics'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Nature\'s Goodness. A Healthier Way of Living.'**
  String get tagline;

  /// No description provided for @organicCertified.
  ///
  /// In en, this message translates to:
  /// **'100% Certified Organic'**
  String get organicCertified;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search organic products...'**
  String get searchHint;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get navFamily;

  /// No description provided for @navCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Midnight Forest Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Organic Linen Light'**
  String get themeLight;

  /// No description provided for @bestsellers.
  ///
  /// In en, this message translates to:
  /// **'Curated Bestsellers'**
  String get bestsellers;

  /// No description provided for @exploreCollection.
  ///
  /// In en, this message translates to:
  /// **'Explore Our Collection'**
  String get exploreCollection;

  /// No description provided for @featuredCategories.
  ///
  /// In en, this message translates to:
  /// **'Featured Categories'**
  String get featuredCategories;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by Category'**
  String get filterByCategory;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortPriceLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get sortPriceLowHigh;

  /// No description provided for @sortPriceHighLow.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get sortPriceHighLow;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @itemAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to your cart.'**
  String get itemAddedToCart;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Shopping Cart'**
  String get myCart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Discover our organic products and add them to your cart.'**
  String get cartEmptyMessage;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @shipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shipping;

  /// No description provided for @shippingFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get shippingFree;

  /// No description provided for @taxIncluded.
  ///
  /// In en, this message translates to:
  /// **'incl. VAT'**
  String get taxIncluded;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItem;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @shippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get shippingAddress;

  /// No description provided for @billingAddress.
  ///
  /// In en, this message translates to:
  /// **'Billing Address'**
  String get billingAddress;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Delivery Addresses'**
  String get savedAddresses;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addAddress;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Full Name / Recipient'**
  String get recipient;

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street & House Number'**
  String get street;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @defaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Default Delivery Address'**
  String get defaultAddress;

  /// No description provided for @shippingMethod.
  ///
  /// In en, this message translates to:
  /// **'Shipping Method'**
  String get shippingMethod;

  /// No description provided for @deliveryEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimated Delivery'**
  String get deliveryEstimate;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @creditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit / Debit Card'**
  String get creditCard;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Direct Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @payPal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get payPal;

  /// No description provided for @walletCredit.
  ///
  /// In en, this message translates to:
  /// **'Shopping Credit / Wallet'**
  String get walletCredit;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @memberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get memberships;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ayubo Family'**
  String get familyTitle;

  /// No description provided for @familySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exclusive organic wellness membership'**
  String get familySubtitle;

  /// No description provided for @activeMember.
  ///
  /// In en, this message translates to:
  /// **'Active Member'**
  String get activeMember;

  /// No description provided for @availableCredit.
  ///
  /// In en, this message translates to:
  /// **'Available Credit'**
  String get availableCredit;

  /// No description provided for @storeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Store Discount'**
  String get storeDiscount;

  /// No description provided for @joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get joinNow;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @creditBackGuarantee.
  ///
  /// In en, this message translates to:
  /// **'100% returned to your wallet'**
  String get creditBackGuarantee;

  /// No description provided for @memberPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Membership Privileges'**
  String get memberPrivileges;

  /// No description provided for @tierComparison.
  ///
  /// In en, this message translates to:
  /// **'Tier Comparison'**
  String get tierComparison;

  /// No description provided for @howMembershipWorks.
  ///
  /// In en, this message translates to:
  /// **'How Membership Works'**
  String get howMembershipWorks;

  /// No description provided for @giftVouchers.
  ///
  /// In en, this message translates to:
  /// **'Gift Vouchers'**
  String get giftVouchers;

  /// No description provided for @giftVoucherTitle.
  ///
  /// In en, this message translates to:
  /// **'The Gift of Pure Ceylon Wellness'**
  String get giftVoucherTitle;

  /// No description provided for @buyVoucher.
  ///
  /// In en, this message translates to:
  /// **'Buy Voucher'**
  String get buyVoucher;

  /// No description provided for @voucherDenominations.
  ///
  /// In en, this message translates to:
  /// **'Available Voucher Denominations'**
  String get voucherDenominations;

  /// No description provided for @instantEmailDelivery.
  ///
  /// In en, this message translates to:
  /// **'Instant Email Delivery'**
  String get instantEmailDelivery;

  /// No description provided for @validAllProducts.
  ///
  /// In en, this message translates to:
  /// **'Valid on all store products'**
  String get validAllProducts;

  /// No description provided for @neverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get neverExpires;

  /// No description provided for @claimVoucher.
  ///
  /// In en, this message translates to:
  /// **'Claim Voucher'**
  String get claimVoucher;

  /// No description provided for @myVouchers.
  ///
  /// In en, this message translates to:
  /// **'My Vouchers & Credit'**
  String get myVouchers;

  /// No description provided for @enterVoucherCode.
  ///
  /// In en, this message translates to:
  /// **'Enter voucher code'**
  String get enterVoucherCode;

  /// No description provided for @voucherClaimed.
  ///
  /// In en, this message translates to:
  /// **'Voucher claimed successfully'**
  String get voucherClaimed;

  /// No description provided for @loyaltyRewards.
  ///
  /// In en, this message translates to:
  /// **'Ayubo Loyalty Rewards'**
  String get loyaltyRewards;

  /// No description provided for @loyaltyPoints.
  ///
  /// In en, this message translates to:
  /// **'Reward Points'**
  String get loyaltyPoints;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Your Points Balance'**
  String get pointsBalance;

  /// No description provided for @earnPoints.
  ///
  /// In en, this message translates to:
  /// **'Earn Points on Every Order'**
  String get earnPoints;

  /// No description provided for @redeemPoints.
  ///
  /// In en, this message translates to:
  /// **'Redeem Rewards'**
  String get redeemPoints;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order Number'**
  String get orderNumber;

  /// No description provided for @orderDate.
  ///
  /// In en, this message translates to:
  /// **'Order Date'**
  String get orderDate;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderStatus;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get orderStatusProcessing;

  /// No description provided for @orderStatusShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get orderStatusShipped;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @downloadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Download Receipt (PDF)'**
  String get downloadReceipt;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeUser;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestUser;

  /// No description provided for @placeOrderGermanLaw.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrderGermanLaw;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms and conditions and the cancellation policy.'**
  String get termsAndConditions;

  /// No description provided for @vatNotice.
  ///
  /// In en, this message translates to:
  /// **'All prices include VAT. The VAT breakdown is shown on your order.'**
  String get vatNotice;

  /// No description provided for @payNormally.
  ///
  /// In en, this message translates to:
  /// **'Pay normally'**
  String get payNormally;

  /// No description provided for @payWithMembership.
  ///
  /// In en, this message translates to:
  /// **'Pay with my membership'**
  String get payWithMembership;

  /// No description provided for @sameAsDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Same as the delivery address'**
  String get sameAsDeliveryAddress;

  /// No description provided for @defaultBillingAddress.
  ///
  /// In en, this message translates to:
  /// **'My default billing address'**
  String get defaultBillingAddress;

  /// No description provided for @addDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Add delivery address'**
  String get addDeliveryAddress;

  /// No description provided for @addBillingAddress.
  ///
  /// In en, this message translates to:
  /// **'Add billing address'**
  String get addBillingAddress;

  /// No description provided for @voucherCode.
  ///
  /// In en, this message translates to:
  /// **'Voucher code'**
  String get voucherCode;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order Placed'**
  String get orderPlaced;

  /// No description provided for @orderPaid.
  ///
  /// In en, this message translates to:
  /// **'Order Paid'**
  String get orderPaid;

  /// No description provided for @thankYouOrder.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your order!'**
  String get thankYouOrder;

  /// No description provided for @orderConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment is complete. You will get an email, and you can download your receipt from the order.'**
  String get orderConfirmedMessage;

  /// No description provided for @orderPendingPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Your items are reserved for a short time. Pay now to complete your order.'**
  String get orderPendingPaymentMessage;

  /// No description provided for @viewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get viewOrder;

  /// No description provided for @personalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal Details'**
  String get personalDetails;

  /// No description provided for @managePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Manage your personal information'**
  String get managePersonalInfo;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @accountActivity.
  ///
  /// In en, this message translates to:
  /// **'Account Activity'**
  String get accountActivity;

  /// No description provided for @myFavourites.
  ///
  /// In en, this message translates to:
  /// **'My favourites'**
  String get myFavourites;

  /// No description provided for @availablePoints.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE POINTS'**
  String get availablePoints;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarned;

  /// No description provided for @pointsRefunded.
  ///
  /// In en, this message translates to:
  /// **'Points taken back (refund)'**
  String get pointsRefunded;

  /// No description provided for @loyaltyExplanation.
  ///
  /// In en, this message translates to:
  /// **'You earn points on the money you pay for an order. Points are added when the order is paid.'**
  String get loyaltyExplanation;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'You have not placed an order yet.'**
  String get noOrdersYet;

  /// No description provided for @noVouchersYet.
  ///
  /// In en, this message translates to:
  /// **'You have no vouchers yet. Gift vouchers you buy and your membership credit appear here.'**
  String get noVouchersYet;

  /// No description provided for @noPointsYet.
  ///
  /// In en, this message translates to:
  /// **'No points yet. Your first order will earn some.'**
  String get noPointsYet;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @receiptPdf.
  ///
  /// In en, this message translates to:
  /// **'Receipt (PDF)'**
  String get receiptPdf;

  /// No description provided for @keepOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get keepOrder;

  /// No description provided for @cancelOrderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelOrderConfirmTitle;

  /// No description provided for @cancelOrderConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Your reserved items are released and any membership credit used is given back. This cannot be undone.'**
  String get cancelOrderConfirmMessage;

  /// No description provided for @each.
  ///
  /// In en, this message translates to:
  /// **'each'**
  String get each;

  /// No description provided for @catalogue.
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get catalogue;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProducts;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No Products Found'**
  String get noProductsFound;

  /// No description provided for @noProductsFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Try clearing your search query or choosing another category.'**
  String get noProductsFoundMessage;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @allergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergens;

  /// No description provided for @selectPackSize.
  ///
  /// In en, this message translates to:
  /// **'Select Pack Size:'**
  String get selectPackSize;

  /// No description provided for @sriLankanHeritage.
  ///
  /// In en, this message translates to:
  /// **'SRI LANKAN AYURVEDIC HERITAGE'**
  String get sriLankanHeritage;

  /// No description provided for @homeSupportingText.
  ///
  /// In en, this message translates to:
  /// **'Discover authentic organic products inspired by Sri Lankan traditions and the timeless wisdom of Ayurveda.'**
  String get homeSupportingText;

  /// No description provided for @exploreProducts.
  ///
  /// In en, this message translates to:
  /// **'Explore Products'**
  String get exploreProducts;

  /// No description provided for @discoverFamily.
  ///
  /// In en, this message translates to:
  /// **'Discover Family'**
  String get discoverFamily;

  /// No description provided for @loginToViewCart.
  ///
  /// In en, this message translates to:
  /// **'Log In to View Cart'**
  String get loginToViewCart;

  /// No description provided for @guestCartMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to view your saved cart, sync items across devices, and proceed to checkout.'**
  String get guestCartMessage;

  /// No description provided for @cancelAndContinueBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Cancel and continue browsing'**
  String get cancelAndContinueBrowsing;

  /// No description provided for @popularProducts.
  ///
  /// In en, this message translates to:
  /// **'Popular Products'**
  String get popularProducts;

  /// No description provided for @searchWellness.
  ///
  /// In en, this message translates to:
  /// **'Search products, wellness...'**
  String get searchWellness;

  /// No description provided for @newArrivals.
  ///
  /// In en, this message translates to:
  /// **'New Arrivals'**
  String get newArrivals;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @joinAyuboFamily.
  ///
  /// In en, this message translates to:
  /// **'Join Ayubo Family'**
  String get joinAyuboFamily;

  /// No description provided for @membershipPromoDesc.
  ///
  /// In en, this message translates to:
  /// **'100% shopping credit back & exclusive member savings'**
  String get membershipPromoDesc;

  /// No description provided for @exploreMembership.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreMembership;

  /// No description provided for @giftVoucherPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Gift of Pure Wellness'**
  String get giftVoucherPromoTitle;

  /// No description provided for @giftVoucherPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Digital vouchers delivered instantly by email'**
  String get giftVoucherPromoSubtitle;

  /// No description provided for @sendVoucher.
  ///
  /// In en, this message translates to:
  /// **'Send Voucher'**
  String get sendVoucher;

  /// No description provided for @welcomeGuest.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Ayubo Organics'**
  String get welcomeGuest;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @shopByCategory.
  ///
  /// In en, this message translates to:
  /// **'Shop by Category'**
  String get shopByCategory;

  /// No description provided for @pureCeylonHeritage.
  ///
  /// In en, this message translates to:
  /// **'100% Certified Organic • Ceylon Heritage'**
  String get pureCeylonHeritage;

  /// No description provided for @voucherOnlyProducts.
  ///
  /// In en, this message translates to:
  /// **'Vouchers can only be used for products. Remove gift vouchers and memberships from your cart.'**
  String get voucherOnlyProducts;

  /// No description provided for @voucherMembershipCombine.
  ///
  /// In en, this message translates to:
  /// **'Vouchers cannot be combined with membership payment. Choose \"Pay normally\" above to use a voucher.'**
  String get voucherMembershipCombine;

  /// No description provided for @addVoucherTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a voucher'**
  String get addVoucherTitle;

  /// No description provided for @addVoucherConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Add voucher'**
  String get addVoucherConfirmLabel;

  /// No description provided for @voucherAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Voucher added. Balance {balance}.'**
  String voucherAddedMessage(Object balance);

  /// No description provided for @noVoucherHistory.
  ///
  /// In en, this message translates to:
  /// **'Nothing has happened with this voucher yet.'**
  String get noVoucherHistory;

  /// No description provided for @voucherDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Details & Balance'**
  String get voucherDetailsSubtitle;

  /// No description provided for @voucherValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get voucherValue;

  /// No description provided for @membershipCredit.
  ///
  /// In en, this message translates to:
  /// **'Membership credit'**
  String get membershipCredit;

  /// No description provided for @giftVoucher.
  ///
  /// In en, this message translates to:
  /// **'Gift voucher'**
  String get giftVoucher;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'remaining balance'**
  String get remainingBalance;

  /// No description provided for @originalValue.
  ///
  /// In en, this message translates to:
  /// **'Original value'**
  String get originalValue;

  /// No description provided for @redeemedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Redeemed so far'**
  String get redeemedSoFar;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get validUntil;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @bestsellersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer favorites & organic essentials'**
  String get bestsellersSubtitle;

  /// No description provided for @exploreAyuboFamily.
  ///
  /// In en, this message translates to:
  /// **'Explore Ayubo Family'**
  String get exploreAyuboFamily;

  /// No description provided for @familyPromoTag.
  ///
  /// In en, this message translates to:
  /// **'AYUBO FAMILY'**
  String get familyPromoTag;

  /// No description provided for @familyPromoHeadline.
  ///
  /// In en, this message translates to:
  /// **'Unlock Exclusive Wellness Privileges'**
  String get familyPromoHeadline;

  /// No description provided for @familyBenefitCredit.
  ///
  /// In en, this message translates to:
  /// **'100% shopping credit back on membership'**
  String get familyBenefitCredit;

  /// No description provided for @familyBenefitDiscount.
  ///
  /// In en, this message translates to:
  /// **'Exclusive member discounts on select organics'**
  String get familyBenefitDiscount;

  /// No description provided for @familyBenefitHeritage.
  ///
  /// In en, this message translates to:
  /// **'Pure Ceylon organic wellness privileges'**
  String get familyBenefitHeritage;

  /// No description provided for @experienceAyubo.
  ///
  /// In en, this message translates to:
  /// **'Experience Ayubo Organics'**
  String get experienceAyubo;

  /// No description provided for @experienceAyuboTag.
  ///
  /// In en, this message translates to:
  /// **'OUR PHYSICAL BOUTIQUE'**
  String get experienceAyuboTag;

  /// No description provided for @experienceAyuboSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visit our physical store to experience pure Ceylon organic spices, wellness teas, and Ayurvedic traditions in person.'**
  String get experienceAyuboSubtitle;

  /// No description provided for @shopFeatureOrganic.
  ///
  /// In en, this message translates to:
  /// **'100% Certified Organic'**
  String get shopFeatureOrganic;

  /// No description provided for @shopFeatureFairTrade.
  ///
  /// In en, this message translates to:
  /// **'Direct Fair Trade'**
  String get shopFeatureFairTrade;

  /// No description provided for @shopFeatureAuthentic.
  ///
  /// In en, this message translates to:
  /// **'Authentic Ceylon Heritage'**
  String get shopFeatureAuthentic;

  /// No description provided for @exploreStoreCollection.
  ///
  /// In en, this message translates to:
  /// **'Explore In-Store Collection'**
  String get exploreStoreCollection;

  /// No description provided for @adminConsole.
  ///
  /// In en, this message translates to:
  /// **'Admin Console'**
  String get adminConsole;

  /// No description provided for @adminStoreOps.
  ///
  /// In en, this message translates to:
  /// **'Store Operations & Catalog'**
  String get adminStoreOps;

  /// No description provided for @adminUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsers;

  /// No description provided for @adminProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get adminProducts;

  /// No description provided for @adminCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get adminCategories;

  /// No description provided for @adminTaxRates.
  ///
  /// In en, this message translates to:
  /// **'Tax rates'**
  String get adminTaxRates;

  /// No description provided for @adminMembershipPlans.
  ///
  /// In en, this message translates to:
  /// **'Membership plans'**
  String get adminMembershipPlans;

  /// No description provided for @adminShipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get adminShipping;

  /// No description provided for @adminVouchers.
  ///
  /// In en, this message translates to:
  /// **'Vouchers'**
  String get adminVouchers;

  /// No description provided for @adminOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrders;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminInactive;

  /// No description provided for @adminDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminDraft;

  /// No description provided for @adminPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPublished;

  /// No description provided for @adminArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminArchived;

  /// No description provided for @adminPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPending;

  /// No description provided for @adminProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get adminProcessing;

  /// No description provided for @adminShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get adminShipped;

  /// No description provided for @adminDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get adminDelivered;

  /// No description provided for @adminCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get adminCancelled;

  /// No description provided for @adminExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get adminExpired;

  /// No description provided for @adminUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get adminUsed;

  /// No description provided for @adminPartiallyRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Partially redeemed'**
  String get adminPartiallyRedeemed;

  /// No description provided for @adminOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get adminOnHold;

  /// No description provided for @adminUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get adminUnpaid;

  /// No description provided for @adminPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminPaid;

  /// No description provided for @adminRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get adminRefunded;

  /// No description provided for @adminPartiallyRefunded.
  ///
  /// In en, this message translates to:
  /// **'Partly refunded'**
  String get adminPartiallyRefunded;

  /// No description provided for @adminCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get adminCurrent;

  /// No description provided for @adminEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get adminEnded;

  /// No description provided for @adminUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get adminUpcoming;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get adminRoleCustomer;

  /// No description provided for @adminSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get adminSearch;

  /// No description provided for @adminFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get adminFilter;

  /// No description provided for @adminAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminAll;

  /// No description provided for @adminAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get adminAllStatuses;

  /// No description provided for @adminAllStates.
  ///
  /// In en, this message translates to:
  /// **'All states'**
  String get adminAllStates;

  /// No description provided for @adminAllKinds.
  ///
  /// In en, this message translates to:
  /// **'All kinds'**
  String get adminAllKinds;

  /// No description provided for @adminAllPayments.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get adminAllPayments;

  /// No description provided for @adminNoActiveVariant.
  ///
  /// In en, this message translates to:
  /// **'No active variant'**
  String get adminNoActiveVariant;

  /// No description provided for @adminVariants.
  ///
  /// In en, this message translates to:
  /// **'variant(s)'**
  String get adminVariants;

  /// No description provided for @adminLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminLoadMore;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreate;

  /// No description provided for @adminUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get adminUpdate;

  /// No description provided for @adminActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get adminActions;

  /// No description provided for @adminConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get adminConfirm;

  /// No description provided for @adminDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get adminDetails;

  /// No description provided for @adminNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get adminNone;

  /// No description provided for @adminNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get adminNotAvailable;

  /// No description provided for @adminSearchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, SKU or slug...'**
  String get adminSearchProductsHint;

  /// No description provided for @adminNoProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get adminNoProductsFound;

  /// No description provided for @adminNewProduct.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get adminNewProduct;

  /// No description provided for @adminEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get adminEditProduct;

  /// No description provided for @adminBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get adminBasicInfo;

  /// No description provided for @adminGermanTranslation.
  ///
  /// In en, this message translates to:
  /// **'German (required)'**
  String get adminGermanTranslation;

  /// No description provided for @adminEnglishTranslation.
  ///
  /// In en, this message translates to:
  /// **'English (optional)'**
  String get adminEnglishTranslation;

  /// No description provided for @adminProductName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get adminProductName;

  /// No description provided for @adminProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminProductDescription;

  /// No description provided for @adminIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get adminIngredients;

  /// No description provided for @adminAllergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get adminAllergens;

  /// No description provided for @adminSlug.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get adminSlug;

  /// No description provided for @adminProductType.
  ///
  /// In en, this message translates to:
  /// **'Product type'**
  String get adminProductType;

  /// No description provided for @adminProductStatus.
  ///
  /// In en, this message translates to:
  /// **'Product status'**
  String get adminProductStatus;

  /// No description provided for @adminTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax rate'**
  String get adminTaxRate;

  /// No description provided for @adminAddVariant.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get adminAddVariant;

  /// No description provided for @adminSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get adminSku;

  /// No description provided for @adminPriceGross.
  ///
  /// In en, this message translates to:
  /// **'Price (€ gross)'**
  String get adminPriceGross;

  /// No description provided for @adminPackQuantity.
  ///
  /// In en, this message translates to:
  /// **'Pack quantity'**
  String get adminPackQuantity;

  /// No description provided for @adminUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get adminUnit;

  /// No description provided for @adminEan.
  ///
  /// In en, this message translates to:
  /// **'EAN'**
  String get adminEan;

  /// No description provided for @adminDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get adminDiscount;

  /// No description provided for @adminDiscountNone.
  ///
  /// In en, this message translates to:
  /// **'No discount'**
  String get adminDiscountNone;

  /// No description provided for @adminDiscountPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get adminDiscountPercentage;

  /// No description provided for @adminDiscountFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get adminDiscountFixed;

  /// No description provided for @adminDiscountValue.
  ///
  /// In en, this message translates to:
  /// **'Discount value'**
  String get adminDiscountValue;

  /// No description provided for @adminDiscountPreview.
  ///
  /// In en, this message translates to:
  /// **'Discounted price preview'**
  String get adminDiscountPreview;

  /// No description provided for @adminImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get adminImages;

  /// No description provided for @adminStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get adminStock;

  /// No description provided for @adminStockOnHand.
  ///
  /// In en, this message translates to:
  /// **'On hand'**
  String get adminStockOnHand;

  /// No description provided for @adminStockReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get adminStockReserved;

  /// No description provided for @adminStockAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get adminStockAvailable;

  /// No description provided for @adminManageStock.
  ///
  /// In en, this message translates to:
  /// **'Manage Stock'**
  String get adminManageStock;

  /// No description provided for @adminSaveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get adminSaveProduct;

  /// No description provided for @adminProductSaved.
  ///
  /// In en, this message translates to:
  /// **'Product saved.'**
  String get adminProductSaved;

  /// No description provided for @adminMembershipsManagedUnder.
  ///
  /// In en, this message translates to:
  /// **'Memberships are managed under Admin > Membership plans.'**
  String get adminMembershipsManagedUnder;

  /// No description provided for @adminNoCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get adminNoCategoriesYet;

  /// No description provided for @adminNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get adminNewCategory;

  /// No description provided for @adminEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get adminEditCategory;

  /// No description provided for @adminCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get adminCategoryName;

  /// No description provided for @adminCategoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminCategoryDescription;

  /// No description provided for @adminParentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get adminParentCategory;

  /// No description provided for @adminNoParent.
  ///
  /// In en, this message translates to:
  /// **'None (top level)'**
  String get adminNoParent;

  /// No description provided for @adminSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get adminSortOrder;

  /// No description provided for @adminDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get adminDeleteCategory;

  /// No description provided for @adminDeleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'will be removed. This cannot be undone.'**
  String get adminDeleteCategoryConfirm;

  /// No description provided for @adminCategoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted.'**
  String get adminCategoryDeleted;

  /// No description provided for @adminSubCategories.
  ///
  /// In en, this message translates to:
  /// **'sub-categories'**
  String get adminSubCategories;

  /// No description provided for @adminProductsInCat.
  ///
  /// In en, this message translates to:
  /// **'products'**
  String get adminProductsInCat;

  /// No description provided for @adminSaveCategory.
  ///
  /// In en, this message translates to:
  /// **'Save Category'**
  String get adminSaveCategory;

  /// No description provided for @adminNoPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No membership plans yet.'**
  String get adminNoPlansYet;

  /// No description provided for @adminNewPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get adminNewPlan;

  /// No description provided for @adminEditPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get adminEditPlan;

  /// No description provided for @adminPlanCode.
  ///
  /// In en, this message translates to:
  /// **'Plan code'**
  String get adminPlanCode;

  /// No description provided for @adminPlanPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (€ gross)'**
  String get adminPlanPrice;

  /// No description provided for @adminMemberCount.
  ///
  /// In en, this message translates to:
  /// **'members'**
  String get adminMemberCount;

  /// No description provided for @adminActivatePlan.
  ///
  /// In en, this message translates to:
  /// **'Activate plan?'**
  String get adminActivatePlan;

  /// No description provided for @adminDeactivatePlan.
  ///
  /// In en, this message translates to:
  /// **'Deactivate plan?'**
  String get adminDeactivatePlan;

  /// No description provided for @adminActivatePlanConfirm.
  ///
  /// In en, this message translates to:
  /// **'will be available to buy again.'**
  String get adminActivatePlanConfirm;

  /// No description provided for @adminDeactivatePlanConfirm.
  ///
  /// In en, this message translates to:
  /// **'can no longer be bought.'**
  String get adminDeactivatePlanConfirm;

  /// No description provided for @adminBenefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get adminBenefits;

  /// No description provided for @adminShoppingCredit.
  ///
  /// In en, this message translates to:
  /// **'shopping credit'**
  String get adminShoppingCredit;

  /// No description provided for @adminStoreDiscount.
  ///
  /// In en, this message translates to:
  /// **'discount on all products'**
  String get adminStoreDiscount;

  /// No description provided for @adminCustomPerk.
  ///
  /// In en, this message translates to:
  /// **'Custom perk'**
  String get adminCustomPerk;

  /// No description provided for @adminAddBenefit.
  ///
  /// In en, this message translates to:
  /// **'Add benefit'**
  String get adminAddBenefit;

  /// No description provided for @adminSavePlan.
  ///
  /// In en, this message translates to:
  /// **'Save Plan'**
  String get adminSavePlan;

  /// No description provided for @adminNoBenefits.
  ///
  /// In en, this message translates to:
  /// **'No benefits'**
  String get adminNoBenefits;

  /// No description provided for @adminSearchVouchersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by code, order # or email...'**
  String get adminSearchVouchersHint;

  /// No description provided for @adminIssueVouchers.
  ///
  /// In en, this message translates to:
  /// **'Issue Vouchers'**
  String get adminIssueVouchers;

  /// No description provided for @adminVoucherAmounts.
  ///
  /// In en, this message translates to:
  /// **'Voucher Amounts'**
  String get adminVoucherAmounts;

  /// No description provided for @adminVoucherSuffix.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get adminVoucherSuffix;

  /// No description provided for @adminBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get adminBalance;

  /// No description provided for @adminOriginalValue.
  ///
  /// In en, this message translates to:
  /// **'Original value'**
  String get adminOriginalValue;

  /// No description provided for @adminOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get adminOwner;

  /// No description provided for @adminOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get adminOrderNumber;

  /// No description provided for @adminExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get adminExpires;

  /// No description provided for @adminNeverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get adminNeverExpires;

  /// No description provided for @adminChangeExpiry.
  ///
  /// In en, this message translates to:
  /// **'Change expiry...'**
  String get adminChangeExpiry;

  /// No description provided for @adminRemoveExpiry.
  ///
  /// In en, this message translates to:
  /// **'Remove expiry'**
  String get adminRemoveExpiry;

  /// No description provided for @adminAssignOwner.
  ///
  /// In en, this message translates to:
  /// **'Assign owner...'**
  String get adminAssignOwner;

  /// No description provided for @adminCancelVoucher.
  ///
  /// In en, this message translates to:
  /// **'Cancel voucher'**
  String get adminCancelVoucher;

  /// No description provided for @adminCancelVoucherConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this voucher? The remaining balance will be lost.'**
  String get adminCancelVoucherConfirm;

  /// No description provided for @adminVoucherHistory.
  ///
  /// In en, this message translates to:
  /// **'Voucher History'**
  String get adminVoucherHistory;

  /// No description provided for @adminIssueQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity (1-100)'**
  String get adminIssueQuantity;

  /// No description provided for @adminCustomerEmail.
  ///
  /// In en, this message translates to:
  /// **'Customer email'**
  String get adminCustomerEmail;

  /// No description provided for @adminStaffNote.
  ///
  /// In en, this message translates to:
  /// **'Internal note (optional)'**
  String get adminStaffNote;

  /// No description provided for @adminExpiryOption.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get adminExpiryOption;

  /// No description provided for @adminExpiryDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (3 years)'**
  String get adminExpiryDefault;

  /// No description provided for @adminExpirySpecific.
  ///
  /// In en, this message translates to:
  /// **'Specific date'**
  String get adminExpirySpecific;

  /// No description provided for @adminExpiryNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get adminExpiryNever;

  /// No description provided for @adminNewAmount.
  ///
  /// In en, this message translates to:
  /// **'New Voucher Amount'**
  String get adminNewAmount;

  /// No description provided for @adminAmountValue.
  ///
  /// In en, this message translates to:
  /// **'Amount (€)'**
  String get adminAmountValue;

  /// No description provided for @adminNameGerman.
  ///
  /// In en, this message translates to:
  /// **'German Name'**
  String get adminNameGerman;

  /// No description provided for @adminNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English Name'**
  String get adminNameEnglish;

  /// No description provided for @adminOnSale.
  ///
  /// In en, this message translates to:
  /// **'On Sale'**
  String get adminOnSale;

  /// No description provided for @adminSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get adminSold;

  /// No description provided for @adminAddVoucherAmount.
  ///
  /// In en, this message translates to:
  /// **'Add Voucher Amount'**
  String get adminAddVoucherAmount;

  /// No description provided for @adminSearchOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order #, name or email...'**
  String get adminSearchOrdersHint;

  /// No description provided for @adminNoOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found.'**
  String get adminNoOrdersFound;

  /// No description provided for @adminOrderItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get adminOrderItems;

  /// No description provided for @adminCustomerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get adminCustomerDetails;

  /// No description provided for @adminOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get adminOrderSummary;

  /// No description provided for @adminPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get adminPayments;

  /// No description provided for @adminShipments.
  ///
  /// In en, this message translates to:
  /// **'Shipments & Parcels'**
  String get adminShipments;

  /// No description provided for @adminAddShipment.
  ///
  /// In en, this message translates to:
  /// **'Add shipment...'**
  String get adminAddShipment;

  /// No description provided for @adminCarrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get adminCarrier;

  /// No description provided for @adminTrackingNumber.
  ///
  /// In en, this message translates to:
  /// **'Tracking number'**
  String get adminTrackingNumber;

  /// No description provided for @adminOrderNotes.
  ///
  /// In en, this message translates to:
  /// **'Order Notes'**
  String get adminOrderNotes;

  /// No description provided for @adminAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note...'**
  String get adminAddNote;

  /// No description provided for @adminMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid...'**
  String get adminMarkPaid;

  /// No description provided for @adminAdvanceToProcessing.
  ///
  /// In en, this message translates to:
  /// **'Advance to processing'**
  String get adminAdvanceToProcessing;

  /// No description provided for @adminAdvanceToDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as delivered'**
  String get adminAdvanceToDelivered;

  /// No description provided for @adminRefundOrder.
  ///
  /// In en, this message translates to:
  /// **'Refund order...'**
  String get adminRefundOrder;

  /// No description provided for @adminFullRefund.
  ///
  /// In en, this message translates to:
  /// **'Full refund'**
  String get adminFullRefund;

  /// No description provided for @adminPartialRefund.
  ///
  /// In en, this message translates to:
  /// **'Partial refund'**
  String get adminPartialRefund;

  /// No description provided for @adminRefundAmount.
  ///
  /// In en, this message translates to:
  /// **'Refund amount (€)'**
  String get adminRefundAmount;

  /// No description provided for @adminRefundReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get adminRefundReason;

  /// No description provided for @adminRestockItems.
  ///
  /// In en, this message translates to:
  /// **'Restock returned items'**
  String get adminRestockItems;

  /// No description provided for @adminResendVouchers.
  ///
  /// In en, this message translates to:
  /// **'Resend digital vouchers'**
  String get adminResendVouchers;

  /// No description provided for @adminNoShipmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No shipments added yet.'**
  String get adminNoShipmentsYet;

  /// No description provided for @adminNoNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes added yet.'**
  String get adminNoNotesYet;

  /// No description provided for @adminNoPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet.'**
  String get adminNoPaymentsYet;

  /// No description provided for @adminSearchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email...'**
  String get adminSearchUsersHint;

  /// No description provided for @adminNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get adminNoUsersFound;

  /// No description provided for @adminUserDetails.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get adminUserDetails;

  /// No description provided for @adminAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get adminAccountStatus;

  /// No description provided for @adminAccountEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get adminAccountEnabled;

  /// No description provided for @adminAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminAccountDisabled;

  /// No description provided for @adminEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get adminEmailVerified;

  /// No description provided for @adminEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email unverified'**
  String get adminEmailUnverified;

  /// No description provided for @adminRegisteredOn.
  ///
  /// In en, this message translates to:
  /// **'Registered on'**
  String get adminRegisteredOn;

  /// No description provided for @adminChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get adminChangeRole;

  /// No description provided for @adminDisableAccount.
  ///
  /// In en, this message translates to:
  /// **'Disable account'**
  String get adminDisableAccount;

  /// No description provided for @adminEnableAccount.
  ///
  /// In en, this message translates to:
  /// **'Enable account'**
  String get adminEnableAccount;

  /// No description provided for @adminMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get adminMembership;

  /// No description provided for @adminMemberNumber.
  ///
  /// In en, this message translates to:
  /// **'Member number'**
  String get adminMemberNumber;

  /// No description provided for @adminPauseMembership.
  ///
  /// In en, this message translates to:
  /// **'Pause membership'**
  String get adminPauseMembership;

  /// No description provided for @adminResumeMembership.
  ///
  /// In en, this message translates to:
  /// **'Resume membership'**
  String get adminResumeMembership;

  /// No description provided for @adminCancelMembership.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership'**
  String get adminCancelMembership;

  /// No description provided for @adminJoinedOn.
  ///
  /// In en, this message translates to:
  /// **'Joined on'**
  String get adminJoinedOn;

  /// No description provided for @adminExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on'**
  String get adminExpiresOn;

  /// No description provided for @adminAvailableCredit.
  ///
  /// In en, this message translates to:
  /// **'Available Credit'**
  String get adminAvailableCredit;

  /// No description provided for @adminShippingMethods.
  ///
  /// In en, this message translates to:
  /// **'Shipping Methods'**
  String get adminShippingMethods;

  /// No description provided for @adminNewShippingMethod.
  ///
  /// In en, this message translates to:
  /// **'New shipping method'**
  String get adminNewShippingMethod;

  /// No description provided for @adminEditShippingMethod.
  ///
  /// In en, this message translates to:
  /// **'Edit shipping method'**
  String get adminEditShippingMethod;

  /// No description provided for @adminMethodName.
  ///
  /// In en, this message translates to:
  /// **'Method name'**
  String get adminMethodName;

  /// No description provided for @adminRates.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get adminRates;

  /// No description provided for @adminAddRate.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get adminAddRate;

  /// No description provided for @adminEditRate.
  ///
  /// In en, this message translates to:
  /// **'Edit rate'**
  String get adminEditRate;

  /// No description provided for @adminCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get adminCountry;

  /// No description provided for @adminOrderValueRange.
  ///
  /// In en, this message translates to:
  /// **'Order value range'**
  String get adminOrderValueRange;

  /// No description provided for @adminShippingFee.
  ///
  /// In en, this message translates to:
  /// **'Shipping fee (€)'**
  String get adminShippingFee;

  /// No description provided for @adminAnyOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Any order value'**
  String get adminAnyOrderValue;

  /// No description provided for @adminNewTaxRate.
  ///
  /// In en, this message translates to:
  /// **'New tax rate'**
  String get adminNewTaxRate;

  /// No description provided for @adminTaxCode.
  ///
  /// In en, this message translates to:
  /// **'Tax code'**
  String get adminTaxCode;

  /// No description provided for @adminRatePercent.
  ///
  /// In en, this message translates to:
  /// **'Rate (%)'**
  String get adminRatePercent;

  /// No description provided for @adminValidFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get adminValidFrom;

  /// No description provided for @adminValidTo.
  ///
  /// In en, this message translates to:
  /// **'Valid to'**
  String get adminValidTo;

  /// No description provided for @adminSetEndDate.
  ///
  /// In en, this message translates to:
  /// **'Set end date...'**
  String get adminSetEndDate;

  /// No description provided for @adminStockMovements.
  ///
  /// In en, this message translates to:
  /// **'Stock Movements'**
  String get adminStockMovements;

  /// No description provided for @adminStockLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get adminStockLocations;

  /// No description provided for @adminReceiveGoods.
  ///
  /// In en, this message translates to:
  /// **'Receive goods'**
  String get adminReceiveGoods;

  /// No description provided for @adminAdjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get adminAdjustStock;

  /// No description provided for @adminStocktake.
  ///
  /// In en, this message translates to:
  /// **'Stocktake'**
  String get adminStocktake;

  /// No description provided for @adminNewLocation.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get adminNewLocation;

  /// No description provided for @adminLocationName.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get adminLocationName;

  /// No description provided for @adminMovementReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminMovementReason;

  /// No description provided for @adminReasonReceipt.
  ///
  /// In en, this message translates to:
  /// **'Goods received'**
  String get adminReasonReceipt;

  /// No description provided for @adminReasonAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adminReasonAdjustment;

  /// No description provided for @adminReasonStocktake.
  ///
  /// In en, this message translates to:
  /// **'Stocktake'**
  String get adminReasonStocktake;

  /// No description provided for @adminReasonSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get adminReasonSale;

  /// No description provided for @adminDescribeImage.
  ///
  /// In en, this message translates to:
  /// **'Describe the image'**
  String get adminDescribeImage;

  /// No description provided for @adminAltTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Alt text (optional)'**
  String get adminAltTextLabel;

  /// No description provided for @adminAltTextHelper.
  ///
  /// In en, this message translates to:
  /// **'Read aloud by screen readers and shown if the image cannot load.'**
  String get adminAltTextHelper;

  /// No description provided for @adminUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get adminUpload;

  /// No description provided for @adminImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is larger than 5 MB. Choose a smaller one.'**
  String get adminImageTooLarge;

  /// No description provided for @adminMakeMain.
  ///
  /// In en, this message translates to:
  /// **'Make main'**
  String get adminMakeMain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
