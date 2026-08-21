import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../help/help_content.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/launch_utils.dart';
import '../../../utils/page_transitions.dart';
import '../../../widgets/common/cotrainr_back_button.dart';
import '../../../widgets/profile/account_hub_widgets.dart';
import 'change_password_page.dart';
import 'health_devices_page.dart';
import 'info_pages.dart';
import 'notifications_page.dart';
import 'privacy_security_page.dart';

/// Legacy FAQ entry — same surface as Help Center.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) => const HelpCenterPage();
}

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  HelpCategoryId? _categoryFilter;
  String? _expandedId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<HelpArticle> get _visibleArticles {
    if (_query.trim().isNotEmpty) {
      return HelpContent.search(_query);
    }
    if (_categoryFilter != null) {
      return HelpContent.forCategory(_categoryFilter!);
    }
    return HelpContent.popularArticles;
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  void _openDeepLink(HelpDeepLink link) {
    HapticFeedback.lightImpact();
    final Widget page;
    switch (link) {
      case HelpDeepLink.changePassword:
        page = const ChangePasswordPage();
      case HelpDeepLink.privacySecurity:
        page = const PrivacySecurityPage();
      case HelpDeepLink.healthDevices:
        page = const HealthDevicesPage();
      case HelpDeepLink.notifications:
        page = const NotificationsPage();
      case HelpDeepLink.privacyPolicy:
        page = const PrivacyPolicyPage();
      case HelpDeepLink.termsOfService:
        page = const TermsOfServicePage();
    }
    Navigator.of(context).push(PageTransitions.slideRoute(page));
  }

  Future<void> _emailSupport() async {
    HapticFeedback.lightImpact();
    await LaunchUtils.sendEmail(
      context,
      to: LaunchUtils.supportEmail,
      subject: 'Cotrainr Support Request',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;
    final articles = _visibleArticles;

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Help Center',
        backgroundColor: bg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Semantics(
            label: 'Search help',
            textField: true,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() {
                _query = v;
                _expandedId = null;
              }),
              decoration: InputDecoration(
                hintText: 'Search help…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _expandedId = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AccountHubTheme.cardBg(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: DesignTokens.accentOrange,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (!_isSearching) ...[
            const SizedBox(height: 20),
            Text(
              'Quick help',
              style: AccountHubTheme.sectionTitle(context),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in HelpContent.categories)
                  _CategoryChip(
                    category: cat,
                    selected: _categoryFilter == cat.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _categoryFilter =
                            _categoryFilter == cat.id ? null : cat.id;
                        _expandedId = null;
                      });
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            _isSearching
                ? 'Search results'
                : (_categoryFilter == null
                    ? 'Popular questions'
                    : HelpContent.categories
                        .firstWhere((c) => c.id == _categoryFilter)
                        .title),
            style: AccountHubTheme.sectionTitle(context),
          ),
          const SizedBox(height: 10),
          if (articles.isEmpty)
            HubSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No help articles found',
                    style: AccountHubTheme.rowTitle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try another search, or contact support.',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _emailSupport,
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Contact support'),
                    ),
                  ),
                ],
              ),
            )
          else
            HubSectionCard(
              child: Column(
                children: [
                  for (var i = 0; i < articles.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _FaqTile(
                      article: articles[i],
                      expanded: _expandedId == articles[i].id,
                      onToggle: () {
                        setState(() {
                          _expandedId = _expandedId == articles[i].id
                              ? null
                              : articles[i].id;
                        });
                      },
                      onDeepLink: articles[i].deepLink == null
                          ? null
                          : () => _openDeepLink(articles[i].deepLink!),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Still need help?',
            style: AccountHubTheme.sectionTitle(context),
          ),
          const SizedBox(height: 10),
          HubSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HubActionRow(
                  icon: Icons.email_outlined,
                  title: 'Email Support',
                  subtitle: LaunchUtils.supportEmail,
                  onTap: _emailSupport,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 8),
                  child: Text(
                    "We'll get back to you as soon as possible.",
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                ),
                const Divider(height: 1),
                HubActionRow(
                  icon: Icons.public_rounded,
                  title: 'Visit Cotrainr website',
                  subtitle: 'www.cotrainr.com',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    LaunchUtils.openWebsite(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final HelpCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = DesignTokens.accentOrange;
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 18,
                  color: selected
                      ? accent
                      : cs.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  category.chipLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.article,
    required this.expanded,
    required this.onToggle,
    this.onDeepLink,
  });

  final HelpArticle article;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onDeepLink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    article.question,
                    style: AccountHubTheme.rowTitle(context),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          SelectableText(
            article.answer,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.82),
            ),
          ),
          if (onDeepLink != null && article.deepLinkLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDeepLink,
                child: Text(article.deepLinkLabel!),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
