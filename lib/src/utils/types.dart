bool isPromiseLike(dynamic obj) {
  return isObject(obj) && isFunction(obj.then) && isFunction(obj.catch);
}

bool isObject(dynamic obj) {
  return obj != null && obj is Object;
}

bool isFunction(dynamic obj) {
  return obj is Function;
} 