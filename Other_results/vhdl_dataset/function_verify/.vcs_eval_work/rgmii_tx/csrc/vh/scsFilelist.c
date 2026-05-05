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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2706, 50, 1774947218, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2756, 4104, 1464145427, 0},
  {"./work/64/RGMII_TX_TARGET_TB.sim", "", 0, 2706, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_RGMII_TX_TARGET_TB.sim", "", 6860, 14309, 0, 0},
  {"./UNISIM/64/VCOMPONENTS.sim", "", 21169, 47173, 0, 1},
  {"./work/64/RGMII_TX.sim", "", 68342, 6220, 0, 1},
  {"./work/64/RGMII_TX_TARGET_TB__SIM.sim", "", 74562, 26120, 0, 1},
  {"./work/64/RGMII_TX__BEHAVIORAL.sim", "", 100682, 47435, 0, 1},
  {"./UNISIM/64/ODDR.sim", "", 148117, 6574, 0, 1},
  {"./UNISIM/64/ODDR__BEHAVIORAL.sim", "", 154691, 9971, 0, 1},
  {"./work/64/RGMII_TX.mra", "", 164662, 11, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 11;
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
