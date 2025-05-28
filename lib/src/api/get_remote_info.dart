import '../static_typedefs.dart';
import '../commands/get_remote_info.dart';
import '../utils/assert_parameter.dart';

/// Get information about a remote repository
///
/// [url] - The remote repository URL
///
/// Returns remote repository information
Future<Map<String, dynamic>> getRemoteInfo({
  required String url,
}) async {
  try {
    assertParameter('url', url);
    
    return await getRemoteInfoCommand(
      url: url,
    );
  } catch (err) {
    rethrow;
  }
}