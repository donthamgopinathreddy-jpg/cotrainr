import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/provider_specialty_taxonomy.dart';
import '../../theme/design_tokens.dart';
import 'provider_professional_form_validation.dart';

/// Multi-select specialty chips (role-aware + preserved custom/legacy ids).
class ProviderSpecialtySelector extends StatelessWidget {
  final String providerType;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ProviderSpecialtySelector({
    super.key,
    required this.providerType,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = ProviderSpecialtyTaxonomy.forRole(providerType);
    final optionIds = options.map((s) => s.id).toSet();
    final custom = selectedIds.where((id) => !optionIds.contains(id));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...options.map((s) {
          final selected = selectedIds.contains(s.id);
          return FilterChip(
            label: Text(s.label),
            selected: selected,
            onSelected: (v) {
              HapticFeedback.selectionClick();
              final next = Set<String>.from(selectedIds);
              if (v) {
                next.add(s.id);
              } else {
                next.remove(s.id);
              }
              onChanged(next);
            },
          );
        }),
        ...custom.map(
          (id) => FilterChip(
            label: Text(ProviderSpecialtyTaxonomy.labelFor(id)),
            selected: true,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              final next = Set<String>.from(selectedIds)..remove(id);
              onChanged(next);
            },
          ),
        ),
      ],
    );
  }
}

/// Session mode chips with role-aware labels; stores canonical ids.
class ProviderSessionModeSelector extends StatelessWidget {
  final String providerType;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const ProviderSessionModeSelector({
    super.key,
    required this.providerType,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ProviderSessionModes.all.map((id) {
        final selected = selectedIds.contains(id);
        return FilterChip(
          label: Text(
            ProviderSessionModes.labelFor(id, role: providerType),
          ),
          selected: selected,
          onSelected: (v) {
            HapticFeedback.selectionClick();
            final next = Set<String>.from(selectedIds);
            if (v) {
              next.add(id);
            } else {
              next.remove(id);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

/// Suggested + custom languages multi-select.
class ProviderLanguageSelector extends StatelessWidget {
  final List<String> languages;
  final TextEditingController customController;
  final ValueChanged<List<String>> onChanged;

  const ProviderLanguageSelector({
    super.key,
    required this.languages,
    required this.customController,
    required this.onChanged,
  });

  void _toggle(String lang) {
    HapticFeedback.selectionClick();
    final next = List<String>.from(languages);
    if (next.contains(lang)) {
      next.remove(lang);
    } else {
      next.add(lang);
    }
    onChanged(next);
  }

  void _addCustom() {
    final v = customController.text.trim();
    if (v.isEmpty) return;
    HapticFeedback.selectionClick();
    final next = List<String>.from(languages);
    if (!next.contains(v)) next.add(v);
    customController.clear();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...ProviderProfessionalFormValidation.suggestedLanguages.map((l) {
              final selected = languages.contains(l);
              return FilterChip(
                label: Text(l),
                selected: selected,
                onSelected: (_) => _toggle(l),
              );
            }),
            ...languages
                .where(
                  (l) => !ProviderProfessionalFormValidation.suggestedLanguages
                      .contains(l),
                )
                .map(
                  (l) => InputChip(
                    label: Text(l),
                    onDeleted: () {
                      final next = List<String>.from(languages)..remove(l);
                      onChanged(next);
                    },
                  ),
                ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Add another language',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            IconButton(
              onPressed: _addCustom,
              icon: const Icon(Icons.add_rounded),
              color: DesignTokens.accentOrange,
            ),
          ],
        ),
      ],
    );
  }
}
