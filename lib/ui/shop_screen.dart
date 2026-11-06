import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/services.dart';
import '../game/rules/boosts.dart';
import 'parent_gate.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.ocean,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: s.profile,
          builder: (context, _) {
            final products = s.purchases.products;
            final storeUp = s.purchases.available && products.isNotEmpty;
            // Remove Ads first, then the coin packs in ascending size.
            final sorted = [...products]
              ..sort((a, b) {
                final ra = a.def.coins > 0 ? 1 : 0;
                final rb = b.def.coins > 0 ? 1 : 0;
                return ra != rb ? ra - rb : a.def.coins.compareTo(b.def.coins);
              });
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (!storeUp)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      key: TestIds.shopUnavailable,
                      child: Text('Store unavailable right now.'),
                    ),
                  ),
                if (storeUp)
                  for (final p in sorted)
                    KidPanel(
                      child: ListTile(
                        leading: p.def.coins > 0
                            ? const CoinIcon(size: 32)
                            : null,
                        title: Text(p.def.title),
                        subtitle: Text(p.def.description),
                        trailing: _owned(s, p.def)
                            ? const Chip(label: Text('Owned'))
                            : FilledButton(
                                key: TestIds.shopBuy(p.def.id),
                                onPressed: () => _buy(context, s, p.def.id),
                                child: Text(p.price),
                              ),
                      ),
                    ),
                // Boosts: coins only, no parent gate (no real money).
                const Padding(
                  key: TestIds.shopBoosts,
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(
                    'Boosts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final def in Boosts.all)
                  KidPanel(
                    child: ListTile(
                      title: Text(def.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(def.description),
                          Text(
                            'You have ${s.profile.itemCount(def.key)}',
                            key: TestIds.shopItemCount(def.key),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        key: TestIds.shopItemBuy(def.key),
                        onPressed: () => _buyBoost(context, s, def),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${def.price} '),
                            const CoinIcon(size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Real-money purchases always go through the parent gate first.
  Future<void> _buy(BuildContext context, Services s, String id) async {
    if (await showParentGate(context, s.parentGate)) {
      await s.purchases.buy(id);
    }
  }

  /// Boosts cost coins only; refuses when the coins are short.
  Future<void> _buyBoost(BuildContext context, Services s, BoostDef def) async {
    final ok = await s.profile.buyItem(def.key);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Got 1 ${def.name}.' : 'Not enough coins.'),
        ),
      );
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}
