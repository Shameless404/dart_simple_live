import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';

class FilterButton extends StatelessWidget {
  final bool selected;
  final String text;
  final Function()? onTap;
  const FilterButton({
    this.selected = false,
    required this.text,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppStyle.radius24,
      onTap: onTap,
      child: Container(
        padding: AppStyle.edgeInsetsH12.copyWith(top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : null,
          border: Border.all(
            color: selected ? Colors.white30 : Colors.grey,
          ),
          borderRadius: AppStyle.radius24,
        ),
        child: Text(
          text,
          style: selected
              ? const TextStyle(color: Colors.black)
              : Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.grey,
                  ),
        ),
      ),
    );
  }
}
