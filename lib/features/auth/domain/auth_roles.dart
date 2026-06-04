String normalizeRole(String? role) {
  return (role ?? '').trim().toLowerCase().replaceAll(' ', '_');
}

const seniorDeveloperEmails = <String>{
  'kofiinspirion@gmail.com',
  'ofosumenyabrightkofi@gmail.com',
  'info.yenkasa@gmail.com',
  'ferochidenarius@gmail.com',
};

String normalizeEmail(String? email) {
  return (email ?? '').trim().toLowerCase();
}

bool isSeniorDeveloperEmail(String? email) {
  return seniorDeveloperEmails.contains(normalizeEmail(email));
}

String effectiveRoleForEmail({required String? email, required String? role}) {
  if (isSeniorDeveloperEmail(email)) return 'senior_developer';
  return normalizeRole(role);
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
