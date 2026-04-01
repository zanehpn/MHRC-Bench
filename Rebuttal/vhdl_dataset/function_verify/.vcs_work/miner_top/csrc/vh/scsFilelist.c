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
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2615, 4104, 1464145427, 0},
  {"./64/MINER_TOP_TARGET_TB.sim", "", 0, 2615, 0, 1},
  {"./64/DUMMY_MHDL_CFG_MINER_TOP_TARGET_TB.sim", "", 6719, 43664, 0, 0},
  {"./64/MINER_TOP.sim", "", 50383, 3007, 0, 1},
  {"./64/MINER_TOP_TARGET_TB__TB.sim", "", 53390, 7147, 0, 1},
  {"./64/MINER_TOP__RTL.sim", "", 60537, 62368, 0, 1},
  {"./64/CLK_WIZ_0.sim", "", 122905, 3601, 0, 1},
  {"./64/CLK_WIZ_0__STUB.sim", "", 126506, 5507, 0, 1},
  {"./64/SOC_WRAPPER.sim", "", 132013, 6187, 0, 1},
  {"./64/SOC_WRAPPER__STUB.sim", "", 138200, 10683, 0, 1},
  {"./64/PULSE_CDC.sim", "", 148883, 4079, 0, 1},
  {"./64/PULSE_CDC__RTL.sim", "", 152962, 8320, 0, 1},
  {"./64/SHA256D_WRAPPER.sim", "", 161282, 7077, 0, 1},
  {"./64/SHA256D_WRAPPER__RTL.sim", "", 168359, 48500, 0, 1},
  {"./64/SHA256_TRANSFORM.sim", "", 216859, 5924, 0, 1},
  {"./64/SHA256_TRANSFORM__RTL.sim", "", 222783, 56644, 0, 1},
  {"./64/MINER_TOP.mra", "", 279427, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 17;
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
