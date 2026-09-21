// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:file_picker/file_picker.dart';

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
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    await BlocklistManager.init(); // Load from blocklist.json by default
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

  Future<void> _updateDomain(String oldDomain, String newDomain) async {
    if (newDomain.trim().isEmpty) return;
    await BlocklistManager.updateUserDomain(oldDomain, newDomain);
    await _loadData();
    // Simplified: re-sync all or just update. Here we build final in manager.
    // For VpnController, it might need specific handling if it's incremental.
    await VpnController.removeSite(oldDomain);
    await VpnController.addSite(newDomain);
  }

  Future<void> _updateKeyword(String oldKeyword, String newKeyword) async {
    if (newKeyword.trim().isEmpty) return;
    await BlocklistManager.updateUserKeyword(oldKeyword, newKeyword);
    await _loadData();
    await VpnController.removeKeyword(oldKeyword);
    await VpnController.addKeyword(newKeyword);
  }

  Future<void> _showEditDialog(String value, bool isDomain) async {
    final TextEditingController editController = TextEditingController(text: value);
    final String title = isDomain ? 'Edit Domain' : 'Edit Keyword';

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              hintText: isDomain ? 'example.com' : 'keyword',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = editController.text.trim();
                if (newValue.isNotEmpty && newValue != value) {
                  if (isDomain) {
                    await _updateDomain(value, newValue);
                  } else {
                    await _updateKeyword(value, newValue);
                  }
                }
                
                // context.mounted is used for Stateful widgets 
                //while mounted is used for the State object itself.
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.path != null) {
        final file = File(result.path!);
        final jsonString = await file.readAsString();
        await BlocklistManager.importFromJson(jsonString);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Blocklist imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportToFile() async {
    try {
      final jsonString = await BlocklistManager.exportToJson();
      final result = await FilePicker.saveFile(
        dialogTitle: 'Export Blocklist',
        fileName: 'blocklist.json',
        bytes: utf8.encode(jsonString),
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Blocklist exported to $result')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Blocked content'),
          actions: [
            IconButton(
              key: const Key('import_button'),
              icon: const Icon(Icons.file_upload),
              onPressed: _importFromFile,
              tooltip: 'Import blocklist.json',
            ),
            IconButton(
              key: const Key('export_button'),
              icon: const Icon(Icons.file_download),
              onPressed: _exportToFile,
              tooltip: 'Export blocklist.json',
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
          child: userDomains.isEmpty
              ? _buildNoDataView('No blocked domains yet')
              : ListView.builder(
                  itemCount: userDomains.length,
                  itemBuilder: (context, index) {
                    final domain = userDomains[index];
                    return ListTile(
                      title: Text(domain),
                      onTap: () => _showEditDialog(domain, true),
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
          child: userKeywords.isEmpty
              ? _buildNoDataView('No blocked keywords yet')
              : ListView.builder(
                  itemCount: userKeywords.length,
                  itemBuilder: (context, index) {
                    final keyword = userKeywords[index];
                    return ListTile(
                      title: Text(keyword),
                      onTap: () => _showEditDialog(keyword, false),
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

  Widget _buildNoDataView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/no-data.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
