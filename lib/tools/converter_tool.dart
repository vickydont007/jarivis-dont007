import '../core/file_converter.dart';
import 'tool.dart';

List<Tool> getAllConverterTools(FileConverter converter) {
  return [
    ConvertFileTool(converter),
    GetSupportedFormatsTool(converter),
    CheckFormatSupportedTool(converter),
  ];
}

class ConvertFileTool extends Tool {
  final FileConverter _converter;

  ConvertFileTool(this._converter)
      : super(
          name: 'convert_file',
          description: 'Convert a file from one format to another.',
          parameters: [
            const ToolParameter(
              name: 'input_path',
              description: 'Path to the input file',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'output_format',
              description: 'Target format (e.g., "json", "csv", "md")',
              type: ToolParameterType.string,
              required: true,
            ),
            const ToolParameter(
              name: 'output_path',
              description: 'Optional output path (default: same directory with new extension)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final result = await _converter.convertFile(
      inputPath: params['input_path'],
      outputFormat: params['output_format'],
      outputPath: params['output_path'],
    );

    if (result.success) {
      return ToolResult.success(
        'File converted successfully',
        metadata: {
          'outputPath': result.outputPath,
          ...result.metadata ?? {},
        },
      );
    }
    return ToolResult.error(result.error ?? 'Conversion failed');
  }
}

class GetSupportedFormatsTool extends Tool {
  final FileConverter _converter;

  GetSupportedFormatsTool(this._converter)
      : super(
          name: 'get_supported_formats',
          description: 'Get all supported file formats for conversion.',
          parameters: [
            const ToolParameter(
              name: 'category',
              description: 'Optional category filter (text, image, document, audio, video, archive)',
              type: ToolParameterType.string,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final category = params['category'];
    if (category != null) {
      final formats = _converter.getSupportedFormats(category);
      return ToolResult.success({
        'category': category,
        'formats': formats,
      });
    }
    return ToolResult.success(_converter.allSupportedFormats);
  }
}

class CheckFormatSupportedTool extends Tool {
  final FileConverter _converter;

  CheckFormatSupportedTool(this._converter)
      : super(
          name: 'check_format_supported',
          description: 'Check if a file format is supported for conversion.',
          parameters: [
            const ToolParameter(
              name: 'format',
              description: 'File format to check (e.g., "json", "pdf")',
              type: ToolParameterType.string,
              required: true,
            ),
          ],
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> params) async {
    final supported = _converter.isFormatSupported(params['format']);
    return ToolResult.success({
      'format': params['format'],
      'supported': supported,
    });
  }
}
