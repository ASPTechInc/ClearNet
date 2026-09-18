// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports:
import 'package:clearnet/data/controllers/vpn_controller.dart';
import 'package:clearnet/data/services/blocklist_manager.dart';

class BlockedSitesScreen extends StatefulWidget {
  const BlockedSitesScreen({super.key});

  @override
  State<BlockedSitesScreen> createState() => _BlockedSitesScreenState();
}

class _BlockedSitesScreenState extends State<BlockedSitesScreen> {
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();

  List<String> userDomains = [];
  List<String> userKeywords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final domains = await BlocklistManager.loadUserDomains();
    final keywords = await BlocklistManager.loadUserKeywords();
    setState(() {
      userDomains = domains;
      userKeywords = keywords;
    });
  }

  Future<void> _addDomain() async {
    final domain = _domainController.text.trim();
    if (domain.isNotEmpty) {
      await BlocklistManager.addUserDomain(domain);
      _domainController.clear();
      await _loadData();
      // Notify VPN (simplistic approach: restart or just add)
      await VpnController.addSite(domain);
    }
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isNotEmpty) {
      await BlocklistManager.addUserKeyword(keyword);
      _keywordController.clear();
      await _loadData();
      await VpnController.addKeyword(keyword);
    }
  }

  Future<void> _removeDomain(String domain) async {
    await BlocklistManager.removeUserDomain(domain);
    await _loadData();
    await VpnController.removeSite(domain);
  }

  Future<void> _removeKeyword(String keyword) async {
    await BlocklistManager.removeUserKeyword(keyword);
    await _loadData();
    await VpnController.removeKeyword(keyword);
  }

  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export / Import JSON'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final json = await BlocklistManager.exportToJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Export to Clipboard'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showImportInput(),
                icon: const Icon(Icons.paste),
                label: const Text('Import from Text'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paste Blocklist JSON'),
          content: TextField(
            key: const Key('import_json_input'),
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '{"domains": ["example.com"], "keywords": ["badword"]}',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await BlocklistManager.importFromJson(controller.text);
                  await _loadData();
                  if (mounted) {
                    Navigator.pop(context); // Close input
                    Navigator.pop(context); // Close main dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Blocklist imported successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Blocked Content'),
          actions: [
            IconButton(
              key: const Key('import_export_button'),
              icon: const Icon(Icons.swap_vert),
              onPressed: _showImportExportDialog,
              tooltip: 'Import/Export',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Domains', icon: Icon(Icons.language)),
              Tab(text: 'Keywords', icon: Icon(Icons.text_format)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDomainList(),
            _buildKeywordList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('domain_input'),
                  controller: _domainController,
                  decoration: const InputDecoration(
                    labelText: 'Add domain (e.g. example.com)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('add_domain_button'),
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 40),
                onPressed: _addDomain,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'User-added domains are merged with the built-in blocklist.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: userDomains.length,
            itemBuilder: (context, index) {
              final domain = userDomains[index];
              return ListTile(
                title: Text(domain),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeDomain(domain),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('keyword_input'),
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Add keyword (e.g. gambling)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('add_keyword_button'),
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 40),
                onPressed: _addKeyword,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Keywords are used to block content in apps and websites.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: userKeywords.length,
            itemBuilder: (context, index) {
              final keyword = userKeywords[index];
              return ListTile(
                title: Text(keyword),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeKeyword(keyword),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
