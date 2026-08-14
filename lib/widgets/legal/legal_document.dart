import 'package:flutter/material.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/auth_theme.dart';
import '../../utils/launch_utils.dart';

class LegalSectionData {
  const LegalSectionData({
    required this.number,
    required this.title,
    required this.body,
    this.callout,
  });

  final String number;
  final String title;
  final String body;
  final String? callout;

  String get tocLabel => '$number  $title';
}

class LegalDocumentHeader extends StatelessWidget {
  const LegalDocumentHeader({
    super.key,
    required this.title,
    this.tagline,
    this.versionLabel,
    this.effectiveLabel,
    this.updatedLabel,
  });

  final String title;
  final String? tagline;
  final String? versionLabel;
  final String? effectiveLabel;
  final String? updatedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AuthTheme.primaryText(context),
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: 8),
          Text(
            tagline!,
            style: TextStyle(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AuthTheme.secondaryText(context),
            ),
          ),
        ],
        if (versionLabel != null ||
            effectiveLabel != null ||
            updatedLabel != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (effectiveLabel != null)
                _MetaChip(label: 'Effective $effectiveLabel'),
              if (updatedLabel != null)
                _MetaChip(label: 'Updated $updatedLabel'),
              if (versionLabel != null)
                _MetaChip(label: 'Version $versionLabel'),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AuthTheme.mutedSurface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuthTheme.fieldBorder(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AuthTheme.mutedText(context),
        ),
      ),
    );
  }
}

class LegalSummaryCard extends StatelessWidget {
  const LegalSummaryCard({
    super.key,
    required this.items,
    this.title = 'At a glance',
  });

  final List<String> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuthTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthTheme.fieldBorder(context)),
        boxShadow: AccountHubTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AuthTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF8A1F), Color(0xFFF59E0B)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    item,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AuthTheme.secondaryText(context),
                    ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class LegalTableOfContents extends StatelessWidget {
  const LegalTableOfContents({
    super.key,
    required this.sections,
    required this.onSelect,
  });

  final List<LegalSectionData> sections;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
      decoration: BoxDecoration(
        color: AuthTheme.surfaceElevated(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthTheme.fieldBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CONTENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AuthTheme.mutedText(context),
              ),
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('legal-toc-$i'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          sections[i].number,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF8A1F)
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sections[i].title,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: AuthTheme.primaryText(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AuthTheme.mutedText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({
    super.key,
    required this.number,
    required this.title,
    required this.body,
    this.callout,
  });

  final String number;
  final String title;
  final String body;
  final String? callout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFF8A1F).withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AuthTheme.primaryText(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          body,
          style: TextStyle(
            fontSize: 16,
            height: 1.55,
            color: AuthTheme.primaryText(context).withValues(alpha: 0.9),
          ),
        ),
        if (callout != null) ...[
          const SizedBox(height: 12),
          LegalCallout(child: SelectableText(callout!)),
        ],
      ],
    );
  }
}

class LegalCallout extends StatelessWidget {
  const LegalCallout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AuthTheme.mutedSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            width: 3,
            color: const Color(0xFFFF8A1F).withValues(alpha: 0.85),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AuthTheme.secondaryText(context),
        ),
        child: child,
      ),
    );
  }
}

class LegalContactSection extends StatelessWidget {
  const LegalContactSection({
    super.key,
    this.intro =
        'For privacy, legal or account questions, email Cotrainr Support.',
  });

  final String intro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AuthTheme.primaryText(context),
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          intro,
          style: TextStyle(
            fontSize: 16,
            height: 1.55,
            color: AuthTheme.primaryText(context).withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.email_outlined,
              color: AuthTheme.secondaryText(context),
            ),
            title: Text(LaunchUtils.supportEmail),
            subtitle: const Text('Support'),
            onTap: () => LaunchUtils.sendEmail(
              context,
              to: LaunchUtils.supportEmail,
              subject: 'Privacy & legal',
            ),
          ),
        ),
      ],
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.atAGlance,
    required this.sections,
    this.tagline,
    this.versionLabel,
    this.effectiveLabel,
    this.updatedLabel,
    this.callout,
    this.contact,
  });

  final String title;
  final String? tagline;
  final List<String> atAGlance;
  final List<LegalSectionData> sections;
  final String? versionLabel;
  final String? effectiveLabel;
  final String? updatedLabel;
  final Widget? callout;
  final Widget? contact;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  final _scrollController = ScrollController();
  final _topKey = GlobalKey();
  late final List<GlobalKey> _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = List.generate(widget.sections.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: _topKey,
                child: LegalDocumentHeader(
                  title: widget.title,
                  tagline: widget.tagline,
                  versionLabel: widget.versionLabel,
                  effectiveLabel: widget.effectiveLabel,
                  updatedLabel: widget.updatedLabel,
                ),
              ),
              const SizedBox(height: 16),
              LegalSummaryCard(items: widget.atAGlance),
              if (widget.callout != null) ...[
                const SizedBox(height: 12),
                widget.callout!,
              ],
              const SizedBox(height: 18),
              LegalTableOfContents(
                sections: widget.sections,
                onSelect: (i) => _scrollToKey(_sectionKeys[i]),
              ),
              for (var i = 0; i < widget.sections.length; i++) ...[
                const SizedBox(height: 28),
                KeyedSubtree(
                  key: _sectionKeys[i],
                  child: LegalSection(
                    number: widget.sections[i].number,
                    title: widget.sections[i].title,
                    body: widget.sections[i].body,
                    callout: widget.sections[i].callout,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              widget.contact ?? const LegalContactSection(),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _scrollToKey(_topKey),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: const Text('Back to top'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
