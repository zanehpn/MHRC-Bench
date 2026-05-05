#include "stdio.h"
#ifdef __cplusplus
extern "C" {
#endif
extern char at_least_one_object_file;
extern void *kernel_scs_file_ht_new(const void *, int);
extern int kernel_scs_file_ht_get(void *, const char *, int *);
extern int  strcmp(const char*, const char*);
  typedef struct {
    char* dFileName;
  } lPkgFileInfoStruct;

  typedef struct {
    char* dFileName;
    char* dRealFileName;
    long dFileOffset;
    unsigned long dFileSize;
    int dFileModTime;
    unsigned int simFlag;
  } lFileInfoStruct;

static int lNumOfScsFiles;
  static lFileInfoStruct lFInfoArr[] = {
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2666, 4104, 1464145427, 0},
  {"./64/UART_TARGET_TB.sim", "", 0, 2666, 0, 1},
  {"./64/DUMMY_MHDL_CFG_UART_TARGET_TB.sim", "", 6770, 7649, 0, 0},
  {"./64/UART.sim", "", 14419, 8148, 0, 1},
  {"./64/UART_TARGET_TB__TB.sim", "", 22567, 23264, 0, 1},
  {"./64/UART_CLK_DIV.sim", "", 45831, 4872, 0, 1},
  {"./64/UART_RX.sim", "", 50703, 6424, 0, 1},
  {"./64/UART_TX.sim", "", 57127, 6194, 0, 1},
  {"./64/UART_DEBOUNCER.sim", "", 63321, 3979, 0, 1},
  {"./64/UART__RTL.sim", "", 67300, 23358, 0, 1},
  {"./64/UART_CLK_DIV__RTL.sim", "", 90658, 11194, 0, 1},
  {"./64/UART_RX__STUB.sim", "", 101852, 9175, 0, 1},
  {"./64/UART_PARITY.sim", "", 111027, 5278, 0, 1},
  {"./64/UART_TX__RTL.sim", "", 116305, 40173, 0, 1},
  {"./64/UART_PARITY__RTL.sim", "", 156478, 12464, 0, 1},
  {"./64/UART_DEBOUNCER__RTL.sim", "", 168942, 12902, 0, 1},
  {"./64/UART.mra", "", 181844, 4, 0, 0},
  {"./64/UART_CLK_DIV.mra", "", 181848, 4, 0, 0},
  {"./64/UART_RX.mra", "", 181852, 5, 0, 0},
  {"./64/UART_TX.mra", "", 181857, 4, 0, 0},
  {"./64/UART_CLK_DIV.mra", "", 181861, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 21;
  lNumOfPkgSimFiles = 0;
  if (!ht)
  {
    ht  = kernel_scs_file_ht_new(lFInfoArr, lNumOfScsFiles);
  }
  if (ht && (kernel_scs_file_ht_get(ht, xFileName, &i) == 0))
  { /* found it! The indicator 'i' was set properly. */
    if (xRealFileName)
        *xRealFileName = lFInfoArr[i].dRealFileName;
    *xFileSizePtr = lFInfoArr[i].dFileSize;
    *xFileOffsetPtr = lFInfoArr[i].dFileOffset;
    return 0;
  }
  return 1;
}
int getNextSimFile(char **fn, long *offset)
{
  static int cur;
  for ( ; cur < lNumOfScsFiles; ) {
    if (!lFInfoArr[cur].simFlag) {
      cur++;
      continue;
    }
    *fn = lFInfoArr[cur].dFileName;
    *offset = lFInfoArr[cur].dFileOffset;
    cur++;
    return 1;
  }
  return 0;
}

#ifdef __cplusplus
}
#endif
