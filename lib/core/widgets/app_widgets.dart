import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Переиспользуемые виджеты с едиными стилями

/// Заголовок экрана с иконкой
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Widget>? actions;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = AppTheme.successColor,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.paddingXL,
        AppTheme.paddingLG,
        AppTheme.paddingXL,
        AppTheme.paddingLG,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingSM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor, iconColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppTheme.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.screenTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTheme.screenSubtitle),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Карточка с единым стилем
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.paddingMD),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Кнопка с градиентом
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> colors;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.colors = const [AppTheme.primaryColor, AppTheme.secondaryColor],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Поле ввода с единым стилем
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool readOnly;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        readOnly: readOnly,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: Theme.of(context).textTheme.labelMedium,
          hintStyle: Theme.of(context).textTheme.bodySmall,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppTheme.primaryColor, size: 20)
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            borderSide: const BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMD,
            vertical: AppTheme.paddingMD,
          ),
        ),
      ),
    );
  }
}

/// Секция с заголовком
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingMD),
      child: Text(title.toUpperCase(), style: AppTheme.labelText),
    );
  }
}
