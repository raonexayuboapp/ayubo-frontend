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
