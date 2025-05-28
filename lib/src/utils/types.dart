bool isPromiseLike(dynamic obj) {
  return isObject(obj) && isFunction(obj.then) && isFunction(obj.onError);
}

bool isObject(dynamic obj) {
  return obj != null && obj.runtimeType != String && obj.runtimeType != num && obj.runtimeType != bool;
}

bool isFunction(dynamic obj) {
  return obj is Function;
}