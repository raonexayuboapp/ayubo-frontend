/// ASSUMPTION, the same as on the server: a member whose status is one of these cannot join again.
/// Confirm the status words with the supervisor. Any other status (for example when the credit ran out)
/// lets the customer join again.
const _joinBlockedStatuses = {'active', 'suspended'};

bool membershipBlocksJoining(Map<String, dynamic>? membership) =>
    membership != null && _joinBlockedStatuses.contains(membership['status']);

/// Why joining is not possible, or null when it is.
String? joinBlockedMessage(Map<String, dynamic>? membership) {
  if (!membershipBlocksJoining(membership)) return null;

  return membership!['status'] == 'suspended'
      ? 'Your membership is suspended. Please contact support.'
      : 'You are already a member.';
}