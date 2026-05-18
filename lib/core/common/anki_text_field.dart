import 'package:flutter/material.dart';

class AnKiTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const AnKiTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
    this.onChanged,
  });

  @override
  State<AnKiTextField> createState() => _AnKiTextFieldState();
}

class _AnKiTextFieldState extends State<AnKiTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: widget.onChanged,
          validator: (value) {
            final result = widget.validator?.call(value);
            // On utilise WidgetsBinding pour éviter les erreurs de setState pendant le build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _errorText != result) {
                setState(() {
                  _errorText = result;
                });
              }
            });
            return result;
          },
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(
              widget.prefixIcon,
              color:
                  hasError
                      ? colorScheme.error
                      : (_isFocused
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withOpacity(0.7)),
              size: 22,
            ),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor:
                _isFocused
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child:
              hasError
                  ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 16),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
