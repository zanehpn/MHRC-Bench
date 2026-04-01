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
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2693, 4104, 1464145427, 0},
  {"./64/UART_TX_TARGET_TB.sim", "", 0, 2693, 0, 1},
  {"./64/DUMMY_MHDL_CFG_UART_TX_TARGET_TB.sim", "", 6797, 5523, 0, 0},
  {"./64/UART_TX.sim", "", 12320, 6194, 0, 1},
  {"./64/UART_TX_TARGET_TB__TB.sim", "", 18514, 22997, 0, 1},
  {"./64/UART_CLK_DIV.sim", "", 41511, 4872, 0, 1},
  {"./64/UART_PARITY.sim", "", 46383, 5278, 0, 1},
  {"./64/UART_TX__RTL.sim", "", 51661, 40173, 0, 1},
  {"./64/UART_CLK_DIV__RTL.sim", "", 91834, 11194, 0, 1},
  {"./64/UART_PARITY__RTL.sim", "", 103028, 12464, 0, 1},
  {"./64/UART_TX.mra", "", 115492, 4, 0, 0},
  {"./64/UART_CLK_DIV.mra", "", 115496, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 12;
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
