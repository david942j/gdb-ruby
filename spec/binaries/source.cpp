#include <stdio.h>
int main(int argc, char **argv) {
  if(argc > 1) {
    for(int i=1;i<argc;i++)
      puts(argv[i]);
    return 0;
  }
  int n;
  while(~scanf("%d", &n) && n)
    printf("%d\n", n);
  return 0;
}
