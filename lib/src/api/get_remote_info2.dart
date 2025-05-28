import '../static_typedefs.dart';
import '../commands/get_remote_info2.dart';
import '../utils/assert_parameter.dart';

/// Get information about a remote repository (version 2)
///
/// [url] - The remote repository URL
///
/// Returns remote repository information
Future<Map<String, dynamic>> getRemoteInfo2({
  required String url,
}) async {
  try {
    assertParameter('url', url);
    
    return await getRemoteInfo2Command(
      url: url,
    );
  } catch (err) {
    rethrow;
  }
}