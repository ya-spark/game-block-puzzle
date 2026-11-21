import 'package:flutter/material.dart';
import 'package:game_block_puzzle/block_puzzle.dart';

import 'core/block_puzzle_host.dart';
import 'core/services.dart';
import 'ui/routes.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key, required this.services});
  final Services services;

  @override
  Widget build(BuildContext context) {
    final cfg = services.config;
    final seed = Color(cfg.themeSeedColor);
    return ServicesScope(
      services: services,
      // The game (game_block_puzzle) asks this app for profile, ads, share and so on through this.
      child: BlockPuzzleServicesScope(
        services: BlockPuzzleServicesAdapter(services),
        child: MaterialApp(
          title: cfg.displayName,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: cfg.themeDark ? Brightness.dark : Brightness.light,
            ).copyWith(surface: cfg.themeDark ? const Color(0xFF0F2430) : null),
          ),
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
