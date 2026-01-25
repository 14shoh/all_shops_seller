import 'package:flutter/material.dart';
import '../../../../features/sales/presentation/pages/create_sale_page.dart';
import '../../../../features/sales/presentation/pages/sales_page.dart';
import '../../../../features/products/presentation/pages/products_list_page.dart';
import '../../../../features/products/presentation/pages/add_product_page.dart';
import '../../../../features/debts/presentation/pages/customer_debts_page.dart';
import '../../../../features/debts/presentation/pages/supplier_debts_page.dart';
import '../../../../core/theme/app_theme.dart';
import 'home_page.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CreateSalePage(),
    const SalesPage(),
    const CustomerDebtsPage(),
    const SupplierDebtsPage(),
    const ProductsListPage(),
    const AddProductPage(),
    const HomePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Позволяет открывать конкретную вкладку по deeplink'у /main/<tab>
    final maxIndex = _screens.length - 1;
    _selectedIndex = widget.initialIndex.clamp(0, maxIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _ModernBottomNavBar(
        bottomInset: bottomInset,
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

}

class NavItem {
  final IconData icon;
  final String label;
  final int index;

  NavItem({required this.icon, required this.label, required this.index});
}

class _ModernBottomNavBar extends StatelessWidget {
  final double bottomInset;
  final int selectedIndex;
  final void Function(int index) onTap;

  const _ModernBottomNavBar({
    required this.bottomInset,
    required this.selectedIndex,
    required this.onTap,
  });

  static const int _addIndex = 5;

  @override
  Widget build(BuildContext context) {
    // Адаптивная высота: не будет BOTTOM OVERFLOW на устройствах с нав. кнопками.
    final barPadding = EdgeInsets.fromLTRB(
      AppTheme.paddingMD,
      10,
      AppTheme.paddingMD,
      10 + bottomInset,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: barPadding,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              _NavPillItem(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Продажа',
                isSelected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavPillItem(
                icon: Icons.history_rounded,
                label: 'История',
                isSelected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavPillItem(
                icon: Icons.people_rounded,
                label: 'Долги',
                isSelected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _AddFab(
                  isSelected: selectedIndex == _addIndex,
                  onTap: () => onTap(_addIndex),
                ),
              ),

              _NavPillItem(
                icon: Icons.business_rounded,
                label: 'Фирмы',
                isSelected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavPillItem(
                icon: Icons.inventory_2_rounded,
                label: 'Товары',
                isSelected: selectedIndex == 4,
                onTap: () => onTap(4),
              ),
              _NavPillItem(
                icon: Icons.menu_rounded,
                label: 'Меню',
                isSelected: selectedIndex == 6,
                onTap: () => onTap(6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppTheme.primaryColor : AppTheme.textTertiary;
    final bg = isSelected ? AppTheme.primaryColor.withOpacity(0.10) : Colors.transparent;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _AddFab({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
