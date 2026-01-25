import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class ModernInputBox extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final VoidCallback? onAddTap;
  final LinearGradient? addButtonGradient;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final LinearGradient? borderGradient;

  const ModernInputBox({
    super.key,
    this.controller,
    this.hintText,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.onAddTap,
    this.addButtonGradient,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.focusNode,
    this.borderGradient,
  });

  @override
  State<ModernInputBox> createState() => _ModernInputBoxState();
}

class _ModernInputBoxState extends State<ModernInputBox> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = widget.borderGradient != null && _isFocused
        ? widget.borderGradient!.colors.first
        : (_isFocused ? AppColors.orange : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? (widget.borderGradient?.colors.first ?? AppColors.orange)
                      .withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: _isFocused ? 16 : 12,
              offset: Offset(0, _isFocused ? 8 : 6),
              spreadRadius: _isFocused ? 0.5 : 0,
            ),
          ],
        ),
        child: _isFocused && widget.borderGradient != null
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: widget.borderGradient,
                ),
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20.5),
                  ),
                  child: _buildTextField(colorScheme),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: borderColor != null
                      ? Border.all(
                          color: borderColor.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                ),
                child: _buildTextField(colorScheme),
              ),
      ),
    );
  }

  Widget _buildTextField(ColorScheme colorScheme) {
    return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines ?? widget.maxLines,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          isDense: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: widget.prefixIcon,
                )
              : null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: widget.onAddTap != null
              ? _buildAddButton(colorScheme)
              : widget.suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: widget.suffixIcon,
                    )
                  : null,
          suffixIconConstraints: widget.onAddTap != null
              ? const BoxConstraints(
                  minWidth: 60,
                  minHeight: 40,
                )
              : const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
        ),
    );
  }

  Widget _buildAddButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onAddTap?.call();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: widget.addButtonGradient ??
                const LinearGradient(
                  colors: [AppColors.orange, AppColors.orangeLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (widget.addButtonGradient?.colors.first ??
                        AppColors.orange)
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
