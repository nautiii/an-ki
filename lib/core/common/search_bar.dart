import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Champ de recherche en pilule et bouton d'ajout de l'accueil.
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onAddPressed;

  const SearchBarWidget({super.key, this.onSearchChanged, this.onAddPressed});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onSearchChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      child: Row(
        children: [
          Expanded(
            // Reconstruit sur chaque frappe : le bouton d'effacement apparaît
            // dès qu'il y a du texte, sans attendre une reconstruction du parent.
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.l10n.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  // Pilule : toute la hauteur du champ (≥ 48 dp) est tactile.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.clearSearch,
                          onPressed: _clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: context.l10n.addBirthday,
            onPressed: () {
              _focusNode.unfocus();
              widget.onAddPressed?.call();
            },
            style: IconButton.styleFrom(
              minimumSize: const Size.square(56),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
