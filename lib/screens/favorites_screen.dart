import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/favorite_item.dart';
import '../services/favorite_service.dart';
import '../utils/app_theme.dart';
import '../viewmodels/household_viewmodel.dart';
import 'add_item_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canWriteInventory = context.watch<HouseholdViewModel>().canWriteInventory;

    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: StreamBuilder<List<FavoriteItem>>(
        stream: FavoriteService.instance.watchFavorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _FavoritesMessage(
              icon: Icons.error_outline,
              title: 'Could not load favourites',
              body: 'Pull down or reopen this screen to try again.',
            );
          }

          final favorites = snapshot.data ?? const <FavoriteItem>[];
          if (favorites.isEmpty) {
            return const _FavoritesMessage(
              icon: Icons.star_outline,
              title: 'No favourites yet',
              body: 'Open an inventory item and tap the star to save products you buy often.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingM),
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.star,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(favorite.name),
                        subtitle: Text(_subtitle(favorite)),
                        trailing: IconButton(
                          tooltip: 'Remove favourite',
                          icon: const Icon(Icons.star),
                          onPressed: () => _remove(context, favorite),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: canWriteInventory
                            ? () => _addAgain(context, favorite)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('Add again'),
                      ),
                      if (!canWriteInventory)
                        const Padding(
                          padding: EdgeInsets.only(top: AppTheme.spacingS),
                          child: Text(
                            'Your current household access is read-only.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _subtitle(FavoriteItem favorite) {
    final parts = <String>[
      favorite.category,
      'Qty ${favorite.quantity}',
      if (favorite.location?.trim().isNotEmpty == true) favorite.location!.trim(),
    ];
    return parts.join(' • ');
  }

  static Future<void> _addAgain(
    BuildContext context,
    FavoriteItem favorite,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          initialBarcode: favorite.barcode,
          initialName: favorite.name,
          initialQuantity: favorite.quantity,
          initialCategory: favorite.category,
          initialLocation: favorite.location,
        ),
      ),
    );
  }

  static Future<void> _remove(
    BuildContext context,
    FavoriteItem favorite,
  ) async {
    try {
      await FavoriteService.instance.removeFavorite(favorite);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove favourite.')),
      );
    }
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: AppTheme.spacingM),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spacingS),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
