Future<bool> modified(dynamic entry, dynamic base) async {
  if (entry == null && base == null) return false;
  if (entry != null && base == null) return true;
  if (entry == null && base != null) return true;
  if (await entry.type() == 'tree' && await base.type() == 'tree') {
    return false;
  }
  if (await entry.type() == await base.type() &&
      await entry.mode() == await base.mode() &&
      await entry.oid() == await base.oid()) {
    return false;
  }
  return true;
}
