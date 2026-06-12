import 'package:flutter/material.dart';

class SkillsStoreScreen extends StatefulWidget {
  const SkillsStoreScreen({super.key});

  @override
  State<SkillsStoreScreen> createState() => _SkillsStoreScreenState();
}

class _SkillsStoreScreenState extends State<SkillsStoreScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _skills = [
    {
      'id': '1',
      'name': 'Email Automation',
      'description': 'Automatically send and manage emails',
      'category': 'productivity',
      'author': 'Community',
      'downloads': 1520,
      'rating': 4.5,
      'installed': true,
      'icon': Icons.email,
      'color': Colors.blue,
    },
    {
      'id': '2',
      'name': 'Calendar Sync',
      'description': 'Sync with Google Calendar and Outlook',
      'category': 'productivity',
      'author': 'Hermes Team',
      'downloads': 890,
      'rating': 4.2,
      'installed': true,
      'icon': Icons.calendar_today,
      'color': Colors.green,
    },
    {
      'id': '3',
      'name': 'Code Review',
      'description': 'Automated code review and suggestions',
      'category': 'development',
      'author': 'OpenClaw',
      'downloads': 2100,
      'rating': 4.8,
      'installed': false,
      'icon': Icons.code,
      'color': Colors.purple,
    },
    {
      'id': '4',
      'name': 'Web Scraper',
      'description': 'Extract data from websites',
      'category': 'data',
      'author': 'Community',
      'downloads': 750,
      'rating': 4.0,
      'installed': false,
      'icon': Icons.web,
      'color': Colors.orange,
    },
    {
      'id': '5',
      'name': 'Image Generator',
      'description': 'Generate images using AI',
      'category': 'creative',
      'author': 'Hermes Team',
      'downloads': 3200,
      'rating': 4.9,
      'installed': false,
      'icon': Icons.image,
      'color': Colors.pink,
    },
    {
      'id': '6',
      'name': 'Music Player',
      'description': 'Control Spotify and Apple Music',
      'category': 'entertainment',
      'author': 'Community',
      'downloads': 1100,
      'rating': 4.3,
      'installed': true,
      'icon': Icons.music_note,
      'color': Colors.teal,
    },
    {
      'id': '7',
      'name': 'File Organizer',
      'description': 'Automatically organize files',
      'category': 'productivity',
      'author': 'OpenClaw',
      'downloads': 620,
      'rating': 4.1,
      'installed': false,
      'icon': Icons.folder,
      'color': Colors.indigo,
    },
    {
      'id': '8',
      'name': 'Translation',
      'description': 'Real-time translation support',
      'category': 'utility',
      'author': 'Community',
      'downloads': 1800,
      'rating': 4.6,
      'installed': true,
      'icon': Icons.translate,
      'color': Colors.cyan,
    },
  ];

  List<Map<String, dynamic>> get _filteredSkills {
    return _skills.where((skill) {
      final matchesCategory = _selectedCategory == 'all' || skill['category'] == _selectedCategory;
      final matchesSearch = skill['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          skill['description'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Skills Store',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Refresh skills list
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF161B22),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search skills...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
            ),
          ),

          // Category Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('all', 'All'),
                _buildCategoryChip('productivity', 'Productivity'),
                _buildCategoryChip('development', 'Development'),
                _buildCategoryChip('data', 'Data'),
                _buildCategoryChip('creative', 'Creative'),
                _buildCategoryChip('entertainment', 'Entertainment'),
                _buildCategoryChip('utility', 'Utility'),
              ],
            ),
          ),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', _skills.length.toString()),
                _buildStat('Installed', _skills.where((s) => s['installed']).length.toString()),
                _buildStat('Available', _skills.where((s) => !s['installed']).length.toString()),
              ],
            ),
          ),

          // Skills List
          Expanded(
            child: _filteredSkills.isEmpty
                ? const Center(
                    child: Text(
                      'No skills found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSkills.length,
                    itemBuilder: (context, index) {
                      final skill = _filteredSkills[index];
                      return _buildSkillCard(skill);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedCategory = category),
        selectedColor: const Color(0xFF58A6FF).withValues(alpha: 0.3),
        checkmarkColor: const Color(0xFF58A6FF),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF58A6FF) : Colors.grey,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF58A6FF) : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Skill Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: skill['color'].withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                skill['icon'],
                color: skill['color'],
              ),
            ),
            const SizedBox(width: 16),

            // Skill Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skill['description'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        skill['author'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.download, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(skill['downloads']),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.star, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        skill['rating'].toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Install/Uninstall Button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  skill['installed'] = !skill['installed'];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      skill['installed'] ? 'Installing ${skill['name']}...' : 'Uninstalling ${skill['name']}...',
                    ),
                    backgroundColor: skill['installed'] ? Colors.green : Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                 backgroundColor: skill['installed']
                     ? Colors.orange.withValues(alpha: 0.2)
                     : const Color(0xFF238636),
                foregroundColor: skill['installed'] ? Colors.orange : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(skill['installed'] ? 'Uninstall' : 'Install'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
