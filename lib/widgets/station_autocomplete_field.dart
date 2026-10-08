import 'package:flutter/material.dart';
import '../models/station.dart';
import '../services/station_service.dart';
import '../theme/app_theme.dart';

class StationAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final Widget? prefixIcon;

  const StationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText = 'e.g. CGY',
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<Station>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.trim().isEmpty) {
              return const Iterable<Station>.empty();
            }
            return StationService.search(textEditingValue.text);
          },
          displayStringForOption: (Station option) => option.code,
          onSelected: (Station selection) {
            controller.text = selection.code;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: selection.code.length),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: constraints.maxWidth > 0 ? constraints.maxWidth : 280,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.surfaceContainerLow),
                    itemBuilder: (BuildContext context, int index) {
                      final Station station = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Row(
                          children: [
                            Text(
                              station.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                station.name,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => onSelected(station),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) {
                // keep uppercase
                final upper = val.toUpperCase();
                if (val != upper) {
                  textController.value = textController.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                prefixIcon: prefixIcon,
              ),
            );
          },
        );
      },
    );
  }
}
