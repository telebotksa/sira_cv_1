import 'package:flutter/material.dart';

import '../core/dates.dart';
import 'tr.dart';

/// Read-only field that opens the calendar. Stores `yyyy-MM`, shows the date
/// in the resume language.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.lang,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String lang;
  final ValueChanged<String> onChanged;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _c =
      TextEditingController(text: Dates.format(widget.value, widget.lang));

  @override
  void didUpdateWidget(DateField old) {
    super.didUpdateWidget(old);
    final t = Dates.format(widget.value, widget.lang);
    if (_c.text != t) _c.text = t;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final first = DateTime(1950);
    final last = DateTime(now.year + 10, 12, 31);
    var initial = Dates.parse(widget.value) ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final help = context.trNow('pickDate');
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      initialDatePickerMode: DatePickerMode.year,
      helpText: help,
    );
    if (d != null) widget.onChanged(Dates.toIso(d));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c,
        readOnly: true,
        onTap: _pick,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: widget.value.isEmpty
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: context.tr('clear'),
                  icon: const Icon(Icons.clear),
                  onPressed: () => widget.onChanged(''),
                ),
        ),
      ),
    );
  }
}
