import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../wiki_repository.dart';
import 'page_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.repo});

  final WikiRepository repo;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<PageRef> _results = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String q) => setState(() => _results = widget.repo.search(q));

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _run,
          style: const TextStyle(fontSize: 16, color: AppTheme.text),
          cursorColor: AppTheme.gold,
          decoration: InputDecoration(
            hintText: 'Search the wiki…',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 19),
                    color: AppTheme.textDim,
                    onPressed: () {
                      _controller.clear();
                      _run('');
                    },
                  ),
          ),
        ),
      ),
      body: switch ((query.isEmpty, _results.isEmpty)) {
        (true, _) => const _Hint(),
        (false, true) => _NoResults(query: query),
        _ => ListView.builder(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              bottom: 32,
            ),
            itemCount: _results.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    '${_results.length} result${_results.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              }
              return PageTile(
                repo: widget.repo,
                page: _results[i - 1],
                showCategory: true,
              );
            },
          ),
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 34, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text(
              'Search by name — weapons, bosses, armor,\nrings, spells, locations and more.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 34, color: AppTheme.textFaint),
            const SizedBox(height: 14),
            Text(
              'Nothing found for “$query”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
