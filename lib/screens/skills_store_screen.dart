import 'package:flutter/material.dart';
import '../core/skills_manager.dart';

class SkillsStoreScreen extends StatefulWidget {
  const SkillsStoreScreen({super.key});

  @override
  State<SkillsStoreScreen> createState() => _SkillsStoreScreenState();
}

class _SkillsStoreScreenState extends State<SkillsStoreScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final SkillsManager _skillsManager = SkillsManager();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  void _loadSkills() async {
    // Import skills from both sources
    await _skillsManager.importFromSource('hermes');
    await _skillsManager.importFromSource('openclaw');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filteredSkills = _getFilteredSkills();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.store, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Skills Store',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_skillsManager.skills.length} skills available',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Filter
            Row(
              children: [
                // Search
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search skills...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF161B22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Category Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF161B22),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                      ..._skillsManager.getCategories().map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat))),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value ?? 'all');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Skills List
            Expanded(
              child: filteredSkills.isEmpty
                  ? const Center(
                      child: Text(
                        'No skills found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredSkills.length,
                      itemBuilder: (context, index) {
                        return _buildSkillCard(filteredSkills[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Skill> _getFilteredSkills() {
    var skills = _skillsManager.skills;

    if (_selectedCategory != 'all') {
      skills = skills.where((s) => s.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      skills = skills.where((s) =>
        s.name.toLowerCase().contains(query) ||
        s.description.toLowerCase().contains(query)
      ).toList();
    }

    return skills;
  }

  Widget _buildSkillCard(Skill skill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getCategoryColor(skill.category).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(skill.category),
              color: _getCategoryColor(skill.category),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  skill.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      skill.source,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.category, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      skill.category,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Install Button
          _buildInstallButton(skill),
        ],
      ),
    );
  }

  Widget _buildInstallButton(Skill skill) {
    final isInstalled = _skillsManager.skills.contains(skill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isInstalled ? Colors.green.withOpacity(0.2) : Colors.cyan.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInstalled ? Colors.green : Colors.cyan,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isInstalled) {
              _skillsManager.removeSkill(skill.id);
            } else {
              // Skill is already imported, just show feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${skill.name} is ready to use'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInstalled ? Icons.check : Icons.add,
              color: isInstalled ? Colors.green : Colors.cyan,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isInstalled ? 'Installed' : 'Install',
              style: TextStyle(
                color: isInstalled ? Colors.green : Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'productivity':
        return Colors.blue;
      case 'development':
        return Colors.purple;
      case 'data':
        return Colors.orange;
      case 'creative':
        return Colors.pink;
      case 'entertainment':
        return Colors.teal;
      case 'research':
        return Colors.green;
      case 'utility':
        return Colors.cyan;
      case 'information':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'productivity':
        return Icons.work;
      case 'development':
        return Icons.code;
      case 'data':
        return Icons.data_usage;
      case 'creative':
        return Icons.palette;
      case 'entertainment':
        return Icons.sports_esports;
      case 'research':
        return Icons.science;
      case 'utility':
        return Icons.build;
      case 'information':
        return Icons.info;
      default:
        return Icons.extension;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _skillsManager.dispose();
    super.dispose();
  }
}
