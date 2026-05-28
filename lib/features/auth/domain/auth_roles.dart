String normalizeRole(String? role) {
  return (role ?? '').trim().toLowerCase().replaceAll(' ', '_');
}

bool isAdminRole(String? role) {
  return {'admin', 'super_admin'}.contains(normalizeRole(role));
}

bool canAccessAnalyticsRole(String? role) {
  return isAdminRole(role);
}

bool canAccessModerationRole(String? role) {
  return {
    'admin',
    'super_admin',
    'moderator',
    'senior_developer',
  }.contains(normalizeRole(role));
}
