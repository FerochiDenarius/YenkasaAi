import 'package:flutter/material.dart';

class AppDestination {
  const AppDestination({
    required this.route,
    required this.label,
    required this.icon,
  });

  final String route;
  final String label;
  final IconData icon;
}

class RuntimeCapability {
  const RuntimeCapability({required this.label, required this.value});

  final String label;
  final String value;
}

const primaryDestinations = <AppDestination>[
  AppDestination(
    route: '/chat',
    label: 'AI Chat',
    icon: Icons.smart_toy_outlined,
  ),
  AppDestination(
    route: '/knowledge-base',
    label: 'Knowledge Base',
    icon: Icons.grid_view_rounded,
  ),
  AppDestination(
    route: '/memory',
    label: 'Memory & Saves',
    icon: Icons.bookmark_border_rounded,
  ),
  AppDestination(
    route: '/ingestion',
    label: 'Ingestion',
    icon: Icons.file_upload_outlined,
  ),
];

const secondaryDestinations = <AppDestination>[
  AppDestination(
    route: '/account',
    label: 'Account',
    icon: Icons.person_outline_rounded,
  ),
  AppDestination(
    route: '/admin',
    label: 'Admin',
    icon: Icons.verified_user_outlined,
  ),
  AppDestination(
    route: '/themes',
    label: 'Themes',
    icon: Icons.palette_outlined,
  ),
];

const utilityDestinations = <AppDestination>[
  AppDestination(
    route: '/runtime',
    label: 'Runtime',
    icon: Icons.schedule_rounded,
  ),
  AppDestination(
    route: '/session',
    label: 'Session',
    icon: Icons.history_toggle_off_rounded,
  ),
  AppDestination(route: '/logout', label: 'Logout', icon: Icons.logout_rounded),
];

const runtimeCapabilities = <RuntimeCapability>[
  RuntimeCapability(label: 'Generation', value: 'Vertex AI'),
  RuntimeCapability(label: 'Retrieval', value: 'Chroma + HF'),
  RuntimeCapability(label: 'Future', value: 'Voice + Auth'),
];

String canonicalRoute(String value) {
  final path = Uri.tryParse(value)?.path ?? value;
  if (path.startsWith('/knowledge')) return '/knowledge-base';
  if (path.startsWith('/saved-responses') || path.startsWith('/memory')) {
    return '/memory';
  }
  if (path.startsWith('/platform') || path.startsWith('/control-plane')) {
    return '/control-plane';
  }
  if (path.startsWith('/analytics') ||
      path.startsWith('/moderation') ||
      path.startsWith('/admin')) {
    return '/admin';
  }
  if (path.startsWith('/runtime')) return '/runtime';
  if (path.startsWith('/session')) return '/session';
  if (path.startsWith('/themes')) return '/themes';
  if (path.startsWith('/account')) return '/account';
  if (path.startsWith('/ingestion')) return '/ingestion';
  if (path.startsWith('/chat')) return '/chat';
  if (path.startsWith('/logout')) return '/logout';
  return '/chat';
}

String routeTitle(String route) {
  return switch (canonicalRoute(route)) {
    '/chat' => 'AI Chat',
    '/knowledge-base' => 'Knowledge Base',
    '/memory' => 'Memory & Saves',
    '/ingestion' => 'Ingestion',
    '/account' => 'Account',
    '/admin' => 'Admin',
    '/themes' => 'Themes',
    '/runtime' => 'Runtime',
    '/session' => 'Session',
    '/control-plane' => 'Control Plane',
    '/logout' => 'Logout',
    _ => 'YenkasaAi',
  };
}
