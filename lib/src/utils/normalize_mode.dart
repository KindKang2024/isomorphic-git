int normalizeMode(int mode) {
  int type = mode > 0 ? mode >> 12 : 0;
  if (type != 0x0100 && type != 0x1000 && type != 0x1010 && type != 0x1110) {
    type = 0x1000;
  }
  int permissions = mode & 0x777;
  if ((permissions & 0x001001001) != 0) {
    permissions = 0x755;
  } else {
    permissions = 0x644;
  }
  if (type != 0x1000) permissions = 0;
  return (type << 12) + permissions;
}
