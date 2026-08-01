import 'package:flutter/material.dart';

import '../models.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'category_screen.dart';

/// The category list for one section — the middle rung between the home grid
/// and a page list.
class SectionScreen extends StatelessWidget {
  const SectionScreen({super.key, required this.repo, required this.section});

  final WikiRepository repo;
  final Section section;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentForSection(section.name);
    final cats = section.categories;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassBar(
        title: Text(section.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '${section.pageCount}',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          bottom: 32,
        ),
        itemCount: cats.length,
        itemBuilder: (context, i) => EnterFade(
          delay: Motion.stagger(i, stepMs: 28),
          child: _CategoryRow(
            repo: repo,
            category: cats[i],
            accent: accent,
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.repo,
    required this.category,
    required this.accent,
  });

  final WikiRepository repo;
  final WikiCategory category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Pressable(
        borderRadius: BorderRadius.circular(12),
        onTap: () => CategoryScreen.open(context, repo, category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Text(
                '${category.count}',
                style: const TextStyle(
                    color: AppTheme.textFaint,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
