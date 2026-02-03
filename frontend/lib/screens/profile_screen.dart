import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import 'login_screen.dart';

// Profile screen showing user details and session actions.
class ProfileScreen extends StatelessWidget {
  final String userId; // token
  final String email;
  final String role;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.role,
  });

  // Builds initials from a display name or email.
  String _initialsFromNameOrEmail(String base, String emailFallback) {
    final baseStr = base.trim().isNotEmpty ? base.trim() : emailFallback.split('@').first;
    final parts = baseStr.split(RegExp(r'[._\-\s]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return baseStr.isNotEmpty ? baseStr[0].toUpperCase() : 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // Shortens long strings for display.
  String _short(String s, {int head = 28, int tail = 12}) {
    if (s.length <= head + tail + 3) return s;
    return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ApiService.session;

    final needsLoad = (s?.name == null || (s!.name?.trim().isEmpty ?? true));
    final loadFuture = needsLoad ? ApiService.fetchMe() : Future.value();

    return FutureBuilder<void>(
      future: loadFuture,
      builder: (ctx, snap) {
        final sess = ApiService.session;

        final tokenEffective = (sess?.token?.isNotEmpty ?? false) ? sess!.token : userId;
        final emailEffective = (sess?.email?.isNotEmpty ?? false) ? sess!.email : email;
        final roleEffective  = (sess?.role?.isNotEmpty ?? false)  ? sess!.role  : (role.isEmpty ? 'User' : role);
        final dbName         = (sess?.name?.trim().isNotEmpty ?? false) ? sess!.name!.trim() : '';

        final displayName = dbName.isNotEmpty
            ? dbName
            : (emailEffective.isNotEmpty
                ? emailEffective.split('@').first
                : (sess?.userId != null && sess!.userId!.length >= 8
                    ? sess.userId!.substring(0, 8)
                    : 'User'));

        final initials = _initialsFromNameOrEmail(displayName, emailEffective);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Profile')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              const LanguageSelector(),
              IconButton(
                tooltip: context.tr('Refresh'),
                onPressed: () {
                  ApiService.fetchMe().then((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          userId: userId,
                          email: email,
                          role: role,
                        ),
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF1F6F2),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Welcome!'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withOpacity(.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            roleEffective,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _InfoCard(
                icon: Icons.email_outlined,
                title: context.tr('Email'),
                value: emailEffective,
                copyable: true,
              ),

              _InfoCard(
                icon: Icons.key_outlined,
                title: context.tr('Role'),
                value: roleEffective,
                copyable: false,
              ),

              _InfoCard(
                icon: Icons.fingerprint_outlined,
                title: context.tr('User ID / Token'),
                value: _short(tokenEffective, head: 28, tail: 12),
                fullValueForCopy: tokenEffective,
                copyable: true,
                trailing: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(context.tr('User ID / Token')),
                        content: SelectableText(tokenEffective),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.tr('Close')),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  label: Text(context.tr('Show All')),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: SizedBox(
                  width: 240,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(context.tr('Log Out')),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool copyable;
  final Widget? trailing;
  final String? fullValueForCopy;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.copyable = false,
    this.trailing,
    this.fullValueForCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) trailing!,
              if (copyable) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: context.tr('Copy'),
                  onPressed: () async {
                    final v = fullValueForCopy ?? value;
                    await Clipboard.setData(ClipboardData(text: v));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('Copied'))),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
