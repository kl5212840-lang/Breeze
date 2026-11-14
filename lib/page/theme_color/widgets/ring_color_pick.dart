import 'package:material_ui/material_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';

class ColorPickerPage extends StatefulWidget {
  final Color currentColor;
  final Function(Color) onColorChanged;

  const ColorPickerPage({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  late final _hex = TextEditingController(
    text: _colorText(widget.currentColor),
  );
  final _focus = FocusNode();

  String _colorText(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  void didUpdateWidget(ColorPickerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentColor != widget.currentColor && !_focus.hasFocus) {
      _hex.text = _colorText(widget.currentColor);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(HSVColor color) {
    _focus.unfocus();
    final value = color.toColor();
    _hex.text = _colorText(value);
    widget.onColorChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Keep the established ring/area picker. Its embedded legacy input
          // rewrites its controller during rebuilds, so the app owns the input
          // and uses its own Material, theme and stable editing lifecycle.
          legacy.Material(
            type: legacy.MaterialType.transparency,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extent = (constraints.maxWidth - 30).clamp(44.0, 250.0);
                final hsv = HSVColor.fromColor(widget.currentColor);
                return Padding(
                  padding: const EdgeInsets.all(15),
                  child: SizedBox.square(
                    dimension: extent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          // The package paints at its constrained size; a loose
                          // Stack child otherwise shrinks its canvas to zero.
                          child: ColorPickerHueRing(
                            hsv,
                            _pick,
                            displayThumbColor: true,
                            strokeWidth: 20,
                          ),
                        ),
                        SizedBox.square(
                          dimension: extent / 1.6,
                          child: ColorPickerArea(hsv, _pick, PaletteType.hsv),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const ValueKey('theme-color.hex'),
                    controller: _hex,
                    focusNode: _focus,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: const InputDecoration(labelText: 'Hex'),
                    onChanged: (text) {
                      final color = colorFromHex(text, enableAlpha: false);
                      if (color != null) widget.onColorChanged(color);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
