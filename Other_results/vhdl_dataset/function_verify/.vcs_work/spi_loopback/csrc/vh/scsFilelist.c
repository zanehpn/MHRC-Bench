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
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2734, 4104, 1464145427, 0},
  {"./64/SPI_LOOPBACK_TARGET_TB.sim", "", 0, 2734, 0, 1},
  {"./64/DUMMY_MHDL_CFG_SPI_LOOPBACK_TARGET_TB.sim", "", 6838, 6351, 0, 0},
  {"./64/SPI_LOOPBACK.sim", "", 13189, 6766, 0, 1},
  {"./64/SPI_LOOPBACK_TARGET_TB__TB.sim", "", 19955, 21160, 0, 1},
  {"./64/RST_SYNC.sim", "", 41115, 3468, 0, 1},
  {"./64/CLK_EN_GEN.sim", "", 44583, 4083, 0, 1},
  {"./64/BTN_DEBOUNCE.sim", "", 48666, 4689, 0, 1},
  {"./64/SPI_MASTER.sim", "", 53355, 9594, 0, 1},
  {"./64/SPI_SLAVE.sim", "", 62949, 6690, 0, 1},
  {"./64/SSEG_DRIVER.sim", "", 69639, 5989, 0, 1},
  {"./64/SPI_LOOPBACK__RTL.sim", "", 75628, 47616, 0, 1},
  {"./64/RST_SYNC__RTL.sim", "", 123244, 9144, 0, 1},
  {"./64/CLK_EN_GEN__RTL.sim", "", 132388, 10568, 0, 1},
  {"./64/BTN_DEBOUNCE__RTL.sim", "", 142956, 17258, 0, 1},
  {"./64/SPI_MASTER__RTL.sim", "", 160214, 58186, 0, 1},
  {"./64/SPI_SLAVE__RTL.sim", "", 218400, 33996, 0, 1},
  {"./64/SSEG_DRIVER__RTL.sim", "", 252396, 33268, 0, 1},
  {"./64/SPI_LOOPBACK.mra", "", 285664, 4, 0, 0},
  {"./64/RST_SYNC.mra", "", 285668, 4, 0, 0},
  {"./64/CLK_EN_GEN.mra", "", 285672, 4, 0, 0},
  {"./64/BTN_DEBOUNCE.mra", "", 285676, 4, 0, 0},
  {"./64/BTN_DEBOUNCE.mra", "", 285680, 4, 0, 0},
  {"./64/SPI_MASTER.mra", "", 285684, 4, 0, 0},
  {"./64/SPI_SLAVE.mra", "", 285688, 4, 0, 0},
  {"./64/SSEG_DRIVER.mra", "", 285692, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 26;
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
