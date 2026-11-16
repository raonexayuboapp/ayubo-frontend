/// Membership statuses follow the backend membership workflow.
///
/// Customers can purchase another membership only when they have no
/// membership, or their existing membership is inactive or expired.
///
/// Unknown statuses fail closed to avoid allowing an invalid purchase.
const _joinAllowedStatuses = {'inactive', 'expired'};

String? _membershipStatus(Map<String, dynamic>? membership) {
  if (membership == null) return null;

  return (membership['status'] ?? '').toString().trim().toLowerCase();
}

bool membershipBlocksJoining(Map<String, dynamic>? membership) {
  if (membership == null) return false;

  return !_joinAllowedStatuses.contains(_membershipStatus(membership));
}

/// Why joining is not possible, or null when it is allowed.
String? joinBlockedMessage(Map<String, dynamic>? membership) {
  if (!membershipBlocksJoining(membership)) return null;

  switch (_membershipStatus(membership)) {
    case 'active':
      return 'You are already a member. You can join again when your '
          'shopping credit is exhausted or your membership expires.';

    case 'paused':
      return 'Your membership is paused. You cannot purchase another '
          'membership while it is paused.';

    case 'cancelled':
      return 'Your membership has been cancelled. Please contact support '
          'if you need assistance.';

    default:
      return 'We could not verify your membership status. Please refresh '
          'your membership details or contact support.';
  }
}
