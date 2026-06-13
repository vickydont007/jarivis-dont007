import '../social/facebook_service.dart';
import '../social/social_manager.dart';
import 'tool.dart';

class FacebookPostTool extends Tool {
  final SocialManager _socialManager;

  FacebookPostTool(this._socialManager) : super(
    name: 'facebook_post',
    description: 'Create a post on your Facebook Page. Requires Facebook Page Access Token.',
    parameters: [
      ToolParameter(name: 'message', description: 'The text content of the post', type: ToolParameterType.string, required: true),
      ToolParameter(name: 'image_url', description: 'Optional image URL to include', type: ToolParameterType.string, required: false),
    ],
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final message = args['message'] as String?;
    final imageUrl = args['image_url'] as String?;

    if (message == null || message.isEmpty) {
      return ToolResult(success: false, error: 'message is required');
    }

    try {
      final facebook = _socialManager.getFacebookService();
      if (facebook == null) {
        return ToolResult(success: false, error: 'Facebook not connected. Set Page Access Token and Page ID in Settings.');
      }

      Map<String, dynamic> result;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        result = await facebook.createPostWithImage(message, imageUrl);
      } else {
        result = await facebook.createPost(message);
      }

      if (result['success'] == true) {
        return ToolResult(success: true, data: 'Post created! Post ID: ${result['postId']}');
      } else {
        return ToolResult(success: false, error: 'Failed: ${result['error']}');
      }
    } catch (e) {
      return ToolResult(success: false, error: '$e');
    }
  }
}

class FacebookReadPostsTool extends Tool {
  final SocialManager _socialManager;

  FacebookReadPostsTool(this._socialManager) : super(
    name: 'facebook_read_posts',
    description: 'Read recent posts from your Facebook Page',
    parameters: [
      ToolParameter(name: 'limit', description: 'Number of posts to retrieve (default: 10)', type: ToolParameterType.number, required: false),
    ],
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    try {
      final facebook = _socialManager.getFacebookService();
      if (facebook == null) {
        return ToolResult(success: false, error: 'Facebook not connected.');
      }

      final posts = await facebook.getPosts(limit: limit);
      if (posts.isEmpty) {
        return ToolResult(success: true, data: 'No posts found.');
      }

      final buffer = StringBuffer('Recent Facebook Posts:\n\n');
      for (final post in posts) {
        buffer.write('- ${post['message'] ?? '(no text)'}\n');
        buffer.write('  Posted: ${post['created_time'] ?? 'unknown'}\n');
        buffer.write('  ID: ${post['id']}\n\n');
      }

      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, error: '$e');
    }
  }
}

class FacebookPageInfoTool extends Tool {
  final SocialManager _socialManager;

  FacebookPageInfoTool(this._socialManager) : super(
    name: 'facebook_page_info',
    description: 'Get your Facebook Page information (name, fans, about)',
    parameters: [],
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final facebook = _socialManager.getFacebookService();
      if (facebook == null) {
        return ToolResult(success: false, error: 'Facebook not connected.');
      }

      final info = await facebook.getPageInfo();
      if (info == null) {
        return ToolResult(success: false, error: 'Could not fetch page info.');
      }

      return ToolResult(
        success: true,
        data: 'Page: ${info['name']}\nID: ${info['id']}\nFans: ${info['fan_count'] ?? 'N/A'}\nAbout: ${info['about'] ?? 'N/A'}',
      );
    } catch (e) {
      return ToolResult(success: false, error: '$e');
    }
  }
}

List<Tool> getAllFacebookTools(SocialManager socialManager) {
  return [
    FacebookPostTool(socialManager),
    FacebookReadPostsTool(socialManager),
    FacebookPageInfoTool(socialManager),
  ];
}
