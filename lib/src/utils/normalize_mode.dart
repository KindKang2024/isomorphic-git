int normalizeMode(int mode) {
  int type = mode > 0 ? mode >> 12 : 0;
  if (type != 0b0100 && type != 0b1000 && type != 0b1010 && type != 0b1110) {
    type = 0b1000;
  }
  int permissions = mode & 0o777;
  if ((permissions & 0b001001001) != 0) {
    permissions = 0o755;
  } else {
    permissions = 0o644;
  }
  if (type != 0b1000) permissions = 0;
  return (type << 12) + permissions;
} 